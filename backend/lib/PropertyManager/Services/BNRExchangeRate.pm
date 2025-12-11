package PropertyManager::Services::BNRExchangeRate;

use strict;
use warnings;
use LWP::UserAgent;
use XML::LibXML;
use Try::Tiny;
use DateTime;
use DateTime::Format::ISO8601;

=head1 NAME

PropertyManager::Services::BNRExchangeRate - BNR Exchange Rate Service

=head1 SYNOPSIS

  use PropertyManager::Services::BNRExchangeRate;

  my $service = PropertyManager::Services::BNRExchangeRate->new(
      schema => $schema,
      config => $config
  );

  # Get current rate (fetches from BNR if not cached)
  my $rate = $service->get_current_rate();

  # Get rate for specific date
  my $rate = $service->get_rate('2025-12-09');

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    die "config is required" unless $args{config};

    $args{ua} ||= LWP::UserAgent->new(
        timeout => 30,
        ssl_opts => { verify_hostname => 1 },
    );

    return bless \%args, $class;
}

=head2 get_current_rate

Get current EUR/RON exchange rate.
Fetches from BNR if not already cached for today.
Returns hashref: { rate => 4.9876, date => '2025-12-09', source => 'BNR' }

=cut

sub get_current_rate {
    my ($self) = @_;

    my $today = DateTime->now->ymd;

    return $self->get_rate($today);
}

=head2 get_rate

Get EUR/RON exchange rate for specific date.
Returns cached rate if available, otherwise fetches from BNR.
Falls back to most recent rate if specific date unavailable.

=cut

sub get_rate {
    my ($self, $date) = @_;

    $date ||= DateTime->now->ymd;

    # Try to get cached rate from database
    my $cached = $self->{schema}->resultset('ExchangeRate')->find(
        { rate_date => $date }
    );

    if ($cached) {
        return {
            rate => $cached->eur_ron,
            date => "" . $cached->rate_date,  # Convert to string
            source => $cached->source,
            cached => 1,
        };
    }

    # Not cached, try to fetch from BNR
    my $fetched = $self->fetch_from_bnr();

    if ($fetched && $fetched->{rate}) {
        # Cache the fetched rate
        $self->cache_rate($fetched->{date}, $fetched->{rate}, $fetched->{source});
        return $fetched;
    }

    # BNR fetch failed, get most recent cached rate
    my $most_recent = $self->{schema}->resultset('ExchangeRate')->search(
        {},
        {
            order_by => { -desc => 'rate_date' },
            rows => 1,
        }
    )->single;

    if ($most_recent) {
        return {
            rate => $most_recent->eur_ron,
            date => "" . $most_recent->rate_date,  # Convert to string
            source => $most_recent->source . ' (cached)',
            cached => 1,
            fallback => 1,
        };
    }

    # No rates available at all
    return undef;
}

=head2 fetch_from_bnr

Fetch current exchange rate from BNR XML feed.
Returns hashref with rate data or undef on failure.

=cut

sub fetch_from_bnr {
    my ($self) = @_;

    my $url = $self->{config}{app}{bnr_api_url} || 'https://www.bnr.ro/nbrfxrates.xml';

    my $response;
    try {
        $response = $self->{ua}->get($url);
    } catch {
        warn "Failed to fetch BNR rate: $_";
        return undef;
    };

    unless ($response && $response->is_success) {
        warn "BNR API request failed: " . ($response ? $response->status_line : 'no response');
        return undef;
    }

    my $xml_content = $response->decoded_content;

    # Parse XML
    my $dom;
    try {
        my $parser = XML::LibXML->new();
        $dom = $parser->parse_string($xml_content);
    } catch {
        warn "Failed to parse BNR XML: $_";
        return undef;
    };

    return undef unless $dom;

    # Extract EUR rate
    # BNR XML structure: <DataSet xmlns="http://www.bnr.ro/xsd"><Body><Cube date="..."><Rate currency="EUR">4.9876</Rate></Cube></Body></DataSet>
    my $xc = XML::LibXML::XPathContext->new($dom);

    # Register namespace if present
    my $root = $dom->documentElement();
    my $ns = $root ? $root->namespaceURI() : undef;
    if ($ns) {
        $xc->registerNs('bnr', $ns);
    }

    # Find the Cube with date (try both with and without namespace)
    my @cube_nodes;
    if ($ns) {
        @cube_nodes = $xc->findnodes('//bnr:Body/bnr:Cube[@date]');
    }
    @cube_nodes = $xc->findnodes('//Body/Cube[@date]') unless @cube_nodes;

    my $cube = $cube_nodes[0];
    unless ($cube) {
        warn "Could not find Cube element in BNR XML";
        return undef;
    }

    my $date_str = $cube->getAttribute('date');

    # Find EUR rate (try both with and without namespace)
    my @rate_nodes;
    if ($ns) {
        @rate_nodes = $xc->findnodes('.//bnr:Rate[@currency="EUR"]', $cube);
    }
    @rate_nodes = $xc->findnodes('.//Rate[@currency="EUR"]', $cube) unless @rate_nodes;

    my $rate_node = $rate_nodes[0];
    unless ($rate_node) {
        warn "Could not find EUR rate in BNR XML";
        return undef;
    }

    my $rate_value = $rate_node->textContent;
    $rate_value =~ s/,/./; # Convert comma to decimal point if needed

    # Format to 4 decimal places
    $rate_value = sprintf("%.4f", $rate_value);

    return {
        rate => $rate_value,
        date => $date_str,
        source => 'BNR',
    };
}

=head2 cache_rate

Store exchange rate in database.

=cut

sub cache_rate {
    my ($self, $date, $rate, $source) = @_;

    $source ||= 'BNR';

    try {
        $self->{schema}->resultset('ExchangeRate')->update_or_create(
            {
                rate_date => $date,
                eur_ron => $rate,
                source => $source,
            },
            {
                key => 'rate_date_unique',
            }
        );
    } catch {
        warn "Failed to cache exchange rate: $_";
    };

    return 1;
}

=head2 get_rate_for_invoice_date

Get exchange rate for a specific invoice date.

Logic:
- If invoice date is today or yesterday (max 1 day difference from most recent rate),
  use the most recent cached rate automatically
- For older dates or future dates beyond 1 day, return undef to prompt manual entry
- This ensures current invoices use fresh rates while historical/future invoices
  require explicit rate confirmation

=cut

sub get_rate_for_invoice_date {
    my ($self, $invoice_date) = @_;

    # Convert to DateTime if string
    my $dt;
    if (ref $invoice_date eq 'DateTime') {
        $dt = $invoice_date;
    } else {
        $dt = DateTime::Format::ISO8601->parse_datetime($invoice_date);
    }

    my $invoice_date_str = $dt->ymd;
    my $today = DateTime->now;

    # First, try to fetch fresh rate from BNR (this also caches it)
    my $fetched = $self->fetch_from_bnr();
    if ($fetched && $fetched->{rate}) {
        $self->cache_rate($fetched->{date}, $fetched->{rate}, $fetched->{source});
    }

    # Check if we have exact rate for invoice date
    my $exact_rate = $self->{schema}->resultset('ExchangeRate')->find(
        { rate_date => $invoice_date_str }
    );

    if ($exact_rate) {
        return {
            rate => $exact_rate->eur_ron,
            date => "" . $exact_rate->rate_date,
            source => $exact_rate->source,
            cached => 1,
        };
    }

    # Get most recent cached rate
    my $most_recent = $self->{schema}->resultset('ExchangeRate')->search(
        {},
        {
            order_by => { -desc => 'rate_date' },
            rows => 1,
        }
    )->single;

    unless ($most_recent) {
        # No rates at all - require manual entry
        return undef;
    }

    # Calculate difference between invoice date and most recent rate date
    my $rate_date = DateTime::Format::ISO8601->parse_datetime($most_recent->rate_date);
    my $diff_days = abs($dt->delta_days($rate_date)->in_units('days'));

    # Only auto-use rate if difference is 1 day or less
    # This handles: today's invoice with yesterday's rate (BNR not yet published)
    if ($diff_days <= 1) {
        return {
            rate => $most_recent->eur_ron,
            date => "" . $most_recent->rate_date,
            source => $most_recent->source,
            cached => 1,
            fallback => 1,  # Indicates this is a fallback rate
        };
    }

    # For dates more than 1 day different, require manual entry
    return undef;
}

1;

__END__

=head1 DESCRIPTION

This service fetches EUR/RON exchange rates from the Romanian National Bank (BNR)
and caches them in the database. It provides fallback mechanisms for when rates
are unavailable.

=head1 BNR API

The service uses the BNR daily exchange rates XML feed:
https://www.bnr.ro/nbrfxrates.xml

The XML structure is:
  <DataSet>
    <Body>
      <Cube date="2025-12-09">
        <Rate currency="EUR">4.9876</Rate>
        <Rate currency="USD">4.5123</Rate>
        ...
      </Cube>
    </Body>
  </DataSet>

=head1 CACHING STRATEGY

- Rates are cached in the exchange_rates table by date
- If a rate for the requested date exists in cache, it's returned immediately
- If not cached, the service attempts to fetch from BNR
- If BNR is unavailable, the most recent cached rate is used as fallback
- All fetched rates are automatically cached

=head1 ERROR HANDLING

The service gracefully handles:
- Network failures when accessing BNR
- XML parsing errors
- Missing data in BNR response
- Database errors when caching

In all error cases, it attempts to return a fallback rate or undef.

=head1 AUTHOR

Property Management System

=cut
