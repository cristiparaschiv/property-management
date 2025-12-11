package TestHelper;

use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use JSON::XS;
use FindBin;
use lib "$FindBin::Bin/../../lib";

use PropertyManager::App;
use PropertyManager::Schema;

=head1 NAME

TestHelper - Common test utilities and fixtures

=head1 SYNOPSIS

  use lib "$FindBin::Bin/../lib";
  use TestHelper;

  # Get database schema
  my $schema = TestHelper::schema();

  # Get Plack::Test instance
  my $test = TestHelper::app();

  # Make authenticated request
  my $response = TestHelper::auth_get($test, '/api/tenants');

  # Login and get token
  my $token = TestHelper::login($test);

  # Create test fixtures
  my $tenant = TestHelper::create_test_tenant($schema);

  # Cleanup test data
  TestHelper::cleanup_test_data($schema);

=cut

our $schema;
our $app;
our $test;
our $token;

=head2 schema

Get database schema instance.

=cut

sub schema {
    return $schema if $schema;

    my $config = PropertyManager::App->config;
    my $db_config = $config->{plugins}{DBIC}{default};

    $schema = PropertyManager::Schema->connect(
        $db_config->{dsn},
        $db_config->{user},
        $db_config->{password},
        $db_config->{options} || {},
    );

    return $schema;
}

=head2 app

Get Plack::Test instance for making HTTP requests.

=cut

sub app {
    return $test if $test;

    $app = PropertyManager::App->to_app;
    $test = Plack::Test->create($app);

    return $test;
}

=head2 login

Login as admin user and return JWT token.

=cut

sub login {
    my ($test_obj, $username, $password) = @_;

    $test_obj ||= app();
    $username ||= 'admin';
    $password ||= 'changeme';

    my $req = POST '/api/auth/login',
        Content_Type => 'application/json',
        Content => encode_json({
            username => $username,
            password => $password,
        });

    my $res = $test_obj->request($req);

    unless ($res->is_success) {
        diag("Login failed: " . $res->content);
        return undef;
    }

    my $data = decode_json($res->content);

    if ($data->{success} && $data->{data}{token}) {
        $token = $data->{data}{token};
        return $token;
    }

    return undef;
}

=head2 get_token

Get cached token or login if not cached.

=cut

sub get_token {
    my ($test_obj) = @_;

    return $token if $token;
    return login($test_obj);
}

=head2 auth_get

Make authenticated GET request.

=cut

sub auth_get {
    my ($test_obj, $url, $token_override) = @_;

    my $auth_token = $token_override || get_token($test_obj);

    unless ($auth_token) {
        die "Cannot make authenticated request: no token available";
    }

    my $req = HTTP::Request->new(GET => $url);
    $req->header('Authorization' => "Bearer $auth_token");

    return $test_obj->request($req);
}

=head2 auth_post

Make authenticated POST request.

=cut

sub auth_post {
    my ($test_obj, $url, $data, $token_override) = @_;

    my $auth_token = $token_override || get_token($test_obj);

    unless ($auth_token) {
        die "Cannot make authenticated request: no token available";
    }

    my $req = HTTP::Request->new(POST => $url);
    $req->header('Authorization' => "Bearer $auth_token");
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json($data || {}));

    return $test_obj->request($req);
}

=head2 auth_put

Make authenticated PUT request.

=cut

sub auth_put {
    my ($test_obj, $url, $data, $token_override) = @_;

    my $auth_token = $token_override || get_token($test_obj);

    unless ($auth_token) {
        die "Cannot make authenticated request: no token available";
    }

    my $req = HTTP::Request->new(PUT => $url);
    $req->header('Authorization' => "Bearer $auth_token");
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json($data || {}));

    return $test_obj->request($req);
}

=head2 auth_delete

Make authenticated DELETE request.

=cut

sub auth_delete {
    my ($test_obj, $url, $token_override) = @_;

    my $auth_token = $token_override || get_token($test_obj);

    unless ($auth_token) {
        die "Cannot make authenticated request: no token available";
    }

    my $req = HTTP::Request->new(DELETE => $url);
    $req->header('Authorization' => "Bearer $auth_token");

    return $test_obj->request($req);
}

=head2 decode_response

Decode JSON response body.

=cut

sub decode_response {
    my ($response) = @_;

    return undef unless $response->content;

    my $data;
    eval {
        $data = decode_json($response->content);
    };

    if ($@) {
        diag("Failed to decode JSON: $@");
        diag("Response: " . $response->content);
        return undef;
    }

    return $data;
}

# ============================================================================
# Test Fixtures
# ============================================================================

=head2 create_test_company

Create a test company if none exists.

=cut

sub create_test_company {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    # Check if company already exists
    my $existing = $schema_obj->resultset('Company')->search()->first;
    return $existing if $existing;

    return $schema_obj->resultset('Company')->create({
        name => $params{name} || 'Test Property Management SRL',
        cui_cif => $params{cui_cif} || 'RO12345678',
        j_number => $params{j_number} || 'J40/1234/2025',
        address => $params{address} || '123 Test Street',
        city => $params{city} || 'Bucharest',
        county => $params{county} || 'Bucharest',
        postal_code => $params{postal_code} || '012345',
        bank_name => $params{bank_name} || 'Test Bank',
        iban => $params{iban} || 'RO49AAAA1B31007593840000',
        phone => $params{phone} || '0212345678',
        email => $params{email} || 'company@test.com',
    });
}

=head2 create_test_tenant

Create a test tenant with default utility percentages.

=cut

sub create_test_tenant {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    my $tenant = $schema_obj->resultset('Tenant')->create({
        name => $params{name} || 'Test Tenant',
        address => $params{address} || '123 Test Street',
        city => $params{city} || 'Bucharest',
        county => $params{county} || 'Bucharest',
        email => $params{email} || 'test@example.com',
        phone => $params{phone} || '0212345678',
        rent_amount_eur => $params{rent_amount_eur} || 500.00,
        is_active => defined $params{is_active} ? $params{is_active} : 1,
        contract_start => $params{contract_start} || '2025-01-01',
        contract_end => $params{contract_end},
    });

    # Create default utility percentages if requested
    if ($params{with_percentages}) {
        my $percentages = $params{percentages} || {
            electricity => 40.00,
            gas => 40.00,
            water => 40.00,
            salubrity => 40.00,
        };

        foreach my $utility_type (keys %$percentages) {
            $schema_obj->resultset('TenantUtilityPercentage')->create({
                tenant_id => $tenant->id,
                utility_type => $utility_type,
                percentage => $percentages->{$utility_type},
            });
        }
    }

    return $tenant;
}

=head2 create_test_provider

Create a test utility provider.

=cut

sub create_test_provider {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    return $schema_obj->resultset('UtilityProvider')->create({
        name => $params{name} || 'Test Provider',
        type => $params{type} || 'electricity',
        account_number => $params{account_number} || 'ACC123456',
        address => $params{address} || '456 Provider Street',
        phone => $params{phone} || '0212345679',
        email => $params{email} || 'provider@example.com',
        is_active => defined $params{is_active} ? $params{is_active} : 1,
    });
}

=head2 create_test_received_invoice

Create a test received invoice.

=cut

sub create_test_received_invoice {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    # Create provider if not provided
    my $provider_id = $params{provider_id};
    unless ($provider_id) {
        my $provider = create_test_provider($schema_obj, type => $params{utility_type} || 'electricity');
        $provider_id = $provider->id;
    }

    return $schema_obj->resultset('ReceivedInvoice')->create({
        provider_id => $provider_id,
        invoice_number => $params{invoice_number} || 'INV-' . int(rand(100000)),
        invoice_date => $params{invoice_date} || '2025-12-01',
        due_date => $params{due_date} || '2025-12-15',
        amount => $params{amount} || 1000.00,
        utility_type => $params{utility_type} || 'electricity',
        period_start => $params{period_start} || '2025-11-01',
        period_end => $params{period_end} || '2025-11-30',
        is_paid => $params{is_paid} || 0,
        paid_date => $params{paid_date},
    });
}

=head2 create_test_meter

Create a test electricity meter.

=cut

sub create_test_meter {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    return $schema_obj->resultset('ElectricityMeter')->create({
        name => $params{name} || 'Test Meter',
        location => $params{location} || 'Test Location',
        tenant_id => $params{tenant_id},
        is_general => $params{is_general} || 0,
        meter_number => $params{meter_number} || 'MTR' . int(rand(100000)),
        is_active => defined $params{is_active} ? $params{is_active} : 1,
    });
}

=head2 create_test_meter_reading

Create a test meter reading.

=cut

sub create_test_meter_reading {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    my $meter_id = $params{meter_id};
    unless ($meter_id) {
        my $meter = create_test_meter($schema_obj);
        $meter_id = $meter->id;
    }

    # Calculate previous_reading_value and consumption if not provided
    my $previous_reading_value = $params{previous_reading_value};
    my $consumption = $params{consumption};

    # If previous_reading_value not provided, try to find it
    if (!defined $previous_reading_value && !defined $consumption) {
        my $prev_reading = $schema_obj->resultset('MeterReading')->search(
            {
                meter_id => $meter_id,
                -or => [
                    { period_year => { '<' => $params{period_year} || 2025 } },
                    {
                        period_year => $params{period_year} || 2025,
                        period_month => { '<' => $params{period_month} || 12 }
                    }
                ]
            },
            {
                order_by => [
                    { -desc => 'period_year' },
                    { -desc => 'period_month' }
                ],
                rows => 1
            }
        )->first;

        if ($prev_reading) {
            $previous_reading_value = $prev_reading->reading_value;
        }
    }

    # Calculate consumption from previous_reading_value if provided
    if (defined $previous_reading_value && !defined $consumption) {
        $consumption = ($params{reading_value} || 1000.00) - $previous_reading_value;
    }

    # Default consumption to provided value or 0
    $consumption //= 0;

    return $schema_obj->resultset('MeterReading')->create({
        meter_id => $meter_id,
        reading_date => $params{reading_date} || '2025-12-01',
        reading_value => $params{reading_value} || 1000.00,
        previous_reading_value => $previous_reading_value,
        consumption => $consumption,
        period_month => $params{period_month} || 12,
        period_year => $params{period_year} || 2025,
    });
}

=head2 create_test_exchange_rate

Create a test exchange rate.

=cut

sub create_test_exchange_rate {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    return $schema_obj->resultset('ExchangeRate')->update_or_create({
        rate_date => $params{rate_date} || '2025-12-09',
        eur_ron => $params{eur_ron} || 4.9750,
        source => $params{source} || 'BNR',
    }, {
        key => 'rate_date_unique',
    });
}

=head2 create_test_invoice

Create a test invoice.

=cut

sub create_test_invoice {
    my ($schema_obj, %params) = @_;

    $schema_obj ||= schema();

    # Create tenant if not provided
    my $tenant_id = $params{tenant_id};
    unless ($tenant_id) {
        my $tenant = create_test_tenant($schema_obj);
        $tenant_id = $tenant->id;
    }

    return $schema_obj->resultset('Invoice')->create({
        invoice_number => $params{invoice_number} || 'ARC' . sprintf('%05d', int(rand(100000))),
        invoice_type => $params{invoice_type} || 'rent',
        tenant_id => $tenant_id,
        invoice_date => $params{invoice_date} || '2025-12-09',
        due_date => $params{due_date} || '2025-12-31',
        exchange_rate => $params{exchange_rate} || 4.9750,
        exchange_rate_date => $params{exchange_rate_date} || '2025-12-09',
        subtotal_eur => $params{subtotal_eur},
        subtotal_ron => $params{subtotal_ron} || 2487.50,
        vat_amount => $params{vat_amount} || 0,
        total_ron => $params{total_ron} || 2487.50,
        is_paid => $params{is_paid} || 0,
        paid_date => $params{paid_date},
    });
}

# ============================================================================
# Cleanup
# ============================================================================

=head2 cleanup_test_data

Remove all test data from database.
Use with caution - deletes data!

=cut

sub cleanup_test_data {
    my ($schema_obj) = @_;

    $schema_obj ||= schema();

    # Delete in order to respect foreign keys
    $schema_obj->resultset('InvoiceItem')->delete_all;
    $schema_obj->resultset('Invoice')->delete_all;
    $schema_obj->resultset('UtilityCalculationDetail')->delete_all;
    $schema_obj->resultset('UtilityCalculation')->delete_all;
    $schema_obj->resultset('MeterReading')->delete_all;
    $schema_obj->resultset('ElectricityMeter')->search({ is_general => 0 })->delete_all;
    $schema_obj->resultset('ReceivedInvoice')->delete_all;
    $schema_obj->resultset('UtilityProvider')->delete_all;
    $schema_obj->resultset('TenantUtilityPercentage')->delete_all;
    $schema_obj->resultset('Tenant')->delete_all;

    # Note: We don't delete company, users, or the General meter
    # as they are considered seed data

    return 1;
}

=head2 reset_token_cache

Reset cached authentication token.

=cut

sub reset_token_cache {
    $token = undef;
}

1;

__END__

=head1 DESCRIPTION

TestHelper provides common utilities for testing the PropertyManager application:

- Database schema access
- HTTP testing with Plack::Test
- Authenticated request helpers
- Test data fixtures
- Cleanup utilities

=head1 USAGE

Load this module in your test files:

  use FindBin;
  use lib "$FindBin::Bin/../lib";
  use TestHelper;

Then use the helper functions:

  my $test = TestHelper::app();
  my $schema = TestHelper::schema();
  my $token = TestHelper::login($test);
  my $response = TestHelper::auth_get($test, '/api/tenants');

=head1 FIXTURES

The module provides fixture creators for all major entities:
- create_test_tenant
- create_test_provider
- create_test_received_invoice
- create_test_meter
- create_test_meter_reading
- create_test_exchange_rate
- create_test_invoice

All fixture creators accept optional parameters to customize the created data.

=head1 CLEANUP

Use cleanup_test_data() to remove test data after tests complete.
This should typically be called in a test's END block or cleanup phase.

=head1 AUTHOR

Property Management System

=cut
