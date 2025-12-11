#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::BNRExchangeRate;
use DateTime;

# Get database schema
my $schema = TestHelper::schema();

# Configuration for testing
my $config = {
    app => {
        bnr_api_url => 'https://www.bnr.ro/nbrfxrates.xml',
    },
};

# Mock user agent for testing (to avoid actual HTTP requests in most tests)
package MockUA {
    sub new { bless {}, shift }
    sub get {
        my ($self, $url) = @_;
        return $self->{response} if $self->{response};
        return MockResponse->new(success => 0, status => 500);
    }
}

package MockResponse {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub is_success { shift->{success} }
    sub status_line { shift->{status} || '500 Internal Server Error' }
    sub decoded_content { shift->{content} || '' }
}

# Test plan
plan tests => 15;

# ============================================================================
# Test: Constructor
# ============================================================================

subtest 'Constructor requires schema and config' => sub {
    plan tests => 3;

    eval {
        PropertyManager::Services::BNRExchangeRate->new();
    };
    like($@, qr/schema is required/, 'Dies without schema');

    eval {
        PropertyManager::Services::BNRExchangeRate->new(schema => $schema);
    };
    like($@, qr/config is required/, 'Dies without config');

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );
    isa_ok($service, 'PropertyManager::Services::BNRExchangeRate', 'Creates instance');
};

# ============================================================================
# Test: cache_rate()
# ============================================================================

subtest 'cache_rate() stores rate in database' => sub {
    plan tests => 5;

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );

    my $test_date = '2025-12-09';
    my $test_rate = 4.9750;

    my $result = $service->cache_rate($test_date, $test_rate, 'BNR');
    ok($result, 'cache_rate returns success');

    # Verify it's in the database
    my $cached = $schema->resultset('ExchangeRate')->find({ rate_date => $test_date });
    ok($cached, 'Rate found in database');
    # Use numeric comparison due to decimal precision
    ok(abs($cached->eur_ron - $test_rate) < 0.0001, 'Rate value matches');
    is($cached->source, 'BNR', 'Source matches');

    # Test update
    my $new_rate = 4.9800;
    $service->cache_rate($test_date, $new_rate, 'BNR');
    $cached->discard_changes;
    ok(abs($cached->eur_ron - $new_rate) < 0.0001, 'Rate updated correctly');
};

# ============================================================================
# Test: get_rate() with cached data
# ============================================================================

subtest 'get_rate() returns cached rate' => sub {
    plan tests => 5;

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );

    # Cache a test rate
    my $test_date = '2025-12-08';
    my $test_rate = 4.9650;
    $service->cache_rate($test_date, $test_rate, 'BNR');

    # Retrieve it
    my $result = $service->get_rate($test_date);
    ok($result, 'get_rate returns result');
    ok(abs($result->{rate} - $test_rate) < 0.0001, 'Rate matches');
    is($result->{date}, $test_date, 'Date matches');
    is($result->{source}, 'BNR', 'Source matches');
    ok($result->{cached}, 'Cached flag is set');
};

# ============================================================================
# Test: get_current_rate()
# ============================================================================

subtest 'get_current_rate() returns today\'s rate' => sub {
    plan tests => 3;

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );

    my $today = DateTime->now->ymd;
    my $test_rate = 4.9700;

    # Cache today's rate
    $service->cache_rate($today, $test_rate, 'BNR');

    # Get current rate
    my $result = $service->get_current_rate();
    ok($result, 'get_current_rate returns result');
    is($result->{date}, $today, 'Returns today\'s date');
    ok(abs($result->{rate} - $test_rate) < 0.0001, 'Returns correct rate');
};

# ============================================================================
# Test: fetch_from_bnr() with mock - success
# ============================================================================

subtest 'fetch_from_bnr() parses valid XML' => sub {
    plan tests => 4;

    my $mock_xml = <<'XML';
<?xml version="1.0" encoding="utf-8"?>
<DataSet xmlns="http://www.bnr.ro/xsd">
  <Body>
    <Cube date="2025-12-09">
      <Rate currency="EUR">4.9876</Rate>
      <Rate currency="USD">4.5123</Rate>
    </Cube>
  </Body>
</DataSet>
XML

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(
        success => 1,
        status => 200,
        content => $mock_xml,
    );

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    my $result = $service->fetch_from_bnr();
    ok($result, 'fetch_from_bnr returns result');
    ok(abs($result->{rate} - 4.9876) < 0.0001, 'Rate parsed correctly');
    is($result->{date}, '2025-12-09', 'Date parsed correctly');
    is($result->{source}, 'BNR', 'Source is BNR');
};

# ============================================================================
# Test: fetch_from_bnr() with mock - network failure
# ============================================================================

subtest 'fetch_from_bnr() handles network failure' => sub {
    plan tests => 1;

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(success => 0, status => 500);

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    my $result = $service->fetch_from_bnr();
    ok(!defined $result, 'Returns undef on network failure');
};

# ============================================================================
# Test: fetch_from_bnr() with mock - invalid XML
# ============================================================================

subtest 'fetch_from_bnr() handles invalid XML' => sub {
    plan tests => 1;

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(
        success => 1,
        status => 200,
        content => 'This is not valid XML',
    );

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    my $result = $service->fetch_from_bnr();
    ok(!defined $result, 'Returns undef for invalid XML');
};

# ============================================================================
# Test: fetch_from_bnr() with mock - missing EUR rate
# ============================================================================

subtest 'fetch_from_bnr() handles missing EUR rate' => sub {
    plan tests => 1;

    my $mock_xml = <<'XML';
<?xml version="1.0" encoding="utf-8"?>
<DataSet xmlns="http://www.bnr.ro/xsd">
  <Body>
    <Cube date="2025-12-09">
      <Rate currency="USD">4.5123</Rate>
      <Rate currency="GBP">5.8765</Rate>
    </Cube>
  </Body>
</DataSet>
XML

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(
        success => 1,
        status => 200,
        content => $mock_xml,
    );

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    my $result = $service->fetch_from_bnr();
    ok(!defined $result, 'Returns undef when EUR rate is missing');
};

# ============================================================================
# Test: get_rate() with fallback to most recent
# ============================================================================

subtest 'get_rate() falls back to most recent cached rate' => sub {
    plan tests => 5;

    # Clean up existing rates
    $schema->resultset('ExchangeRate')->delete_all;

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(success => 0);

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    # Cache some rates
    $service->cache_rate('2025-12-01', 4.9500, 'BNR');
    $service->cache_rate('2025-12-05', 4.9600, 'BNR');
    $service->cache_rate('2025-12-07', 4.9700, 'BNR');

    # Try to get rate for future date (not cached, BNR fails)
    my $result = $service->get_rate('2025-12-20');
    ok($result, 'Returns fallback rate');
    ok(abs($result->{rate} - 4.9700) < 0.0001, 'Returns most recent rate');
    is($result->{date}, '2025-12-07', 'Returns most recent date');
    ok($result->{cached}, 'Cached flag is set');
    ok($result->{fallback}, 'Fallback flag is set');
};

# ============================================================================
# Test: get_rate() with no cached data and BNR failure
# ============================================================================

subtest 'get_rate() returns undef when no data available' => sub {
    plan tests => 1;

    # Clean exchange_rates table
    $schema->resultset('ExchangeRate')->delete_all;

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(success => 0);

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    my $result = $service->get_rate('2025-12-20');
    ok(!defined $result, 'Returns undef when no data available');

    # Restore some data for other tests
    $service->cache_rate('2025-12-09', 4.9750, 'BNR');
};

# ============================================================================
# Test: get_rate_for_invoice_date() with DateTime
# ============================================================================

subtest 'get_rate_for_invoice_date() handles DateTime objects' => sub {
    plan tests => 3;

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );

    my $test_date = '2025-12-06';
    my $test_rate = 4.9550;
    $service->cache_rate($test_date, $test_rate, 'BNR');

    my $dt = DateTime->new(year => 2025, month => 12, day => 6);
    my $result = $service->get_rate_for_invoice_date($dt);

    ok($result, 'Returns result for DateTime input');
    is($result->{date}, $test_date, 'Date matches');
    ok(abs($result->{rate} - $test_rate) < 0.0001, 'Rate matches');
};

# ============================================================================
# Test: get_rate_for_invoice_date() with string
# ============================================================================

subtest 'get_rate_for_invoice_date() handles ISO date strings' => sub {
    plan tests => 3;

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );

    my $test_date = '2025-12-04';
    my $test_rate = 4.9450;
    $service->cache_rate($test_date, $test_rate, 'BNR');

    my $result = $service->get_rate_for_invoice_date($test_date);

    ok($result, 'Returns result for string input');
    is($result->{date}, $test_date, 'Date matches');
    ok(abs($result->{rate} - $test_rate) < 0.0001, 'Rate matches');
};

# ============================================================================
# Test: Rate format with comma decimal separator
# ============================================================================

subtest 'fetch_from_bnr() handles comma decimal separator' => sub {
    plan tests => 2;

    my $mock_xml = <<'XML';
<?xml version="1.0" encoding="utf-8"?>
<DataSet xmlns="http://www.bnr.ro/xsd">
  <Body>
    <Cube date="2025-12-09">
      <Rate currency="EUR">4,9876</Rate>
    </Cube>
  </Body>
</DataSet>
XML

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(
        success => 1,
        status => 200,
        content => $mock_xml,
    );

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    my $result = $service->fetch_from_bnr();
    ok($result, 'Parses rate with comma');
    ok(abs($result->{rate} - 4.9876) < 0.0001, 'Comma converted to decimal point');
};

# ============================================================================
# Test: Integration - fetch and cache
# ============================================================================

subtest 'Integration: fetch from BNR and cache automatically' => sub {
    plan tests => 5;

    my $mock_xml = <<'XML';
<?xml version="1.0" encoding="utf-8"?>
<DataSet xmlns="http://www.bnr.ro/xsd">
  <Body>
    <Cube date="2025-12-10">
      <Rate currency="EUR">5.0000</Rate>
    </Cube>
  </Body>
</DataSet>
XML

    my $mock_ua = MockUA->new();
    $mock_ua->{response} = MockResponse->new(
        success => 1,
        status => 200,
        content => $mock_xml,
    );

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
        ua => $mock_ua,
    );

    # Request a date that's not cached (will trigger fetch)
    my $result = $service->get_rate('2025-12-10');

    ok($result, 'get_rate returns result');
    ok(abs($result->{rate} - 5.0000) < 0.0001, 'Rate from BNR API');
    is($result->{date}, '2025-12-10', 'Date from BNR API');

    # Verify it was cached
    my $cached = $schema->resultset('ExchangeRate')->find({ rate_date => '2025-12-10' });
    ok($cached, 'Rate was cached in database');
    ok(abs($cached->eur_ron - 5.0000) < 0.0001, 'Cached rate matches fetched rate');
};

# ============================================================================
# Test: Multiple sources
# ============================================================================

subtest 'Supports different sources for rates' => sub {
    plan tests => 3;

    my $service = PropertyManager::Services::BNRExchangeRate->new(
        schema => $schema,
        config => $config,
    );

    $service->cache_rate('2025-12-11', 4.9800, 'BNR');
    $service->cache_rate('2025-12-12', 5.0000, 'Manual');
    $service->cache_rate('2025-12-13', 4.9900, 'Fallback');

    my $rate1 = $service->get_rate('2025-12-11');
    my $rate2 = $service->get_rate('2025-12-12');
    my $rate3 = $service->get_rate('2025-12-13');

    is($rate1->{source}, 'BNR', 'Source: BNR');
    is($rate2->{source}, 'Manual', 'Source: Manual');
    is($rate3->{source}, 'Fallback', 'Source: Fallback');
};

done_testing();
