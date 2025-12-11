#!/usr/bin/env perl

=head1 NAME

t/search-api.t - Tests for global search API endpoint

=head1 DESCRIPTION

Test suite for the /api/search endpoint including:
- Authentication requirements
- Query validation
- Search across tenants, invoices, and providers
- Result formatting and limits
- Error handling

=cut

use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Check if we can load the application
BEGIN {
    use_ok('PropertyManager::App') or BAIL_OUT("Cannot load PropertyManager::App");
}

# Create test application
my $app = Dancer2->psgi_app;
ok($app, 'Got app');

my $test = Plack::Test->create($app);

# JSON encoder/decoder
my $json = JSON::MaybeXS->new(utf8 => 1);

=head2 Test Suite Structure

1. Authentication tests
2. Query validation tests
3. Search functionality tests
4. Result format tests
5. Edge case tests

=cut

# ============================================================================
# Authentication Tests
# ============================================================================

subtest 'Authentication Required' => sub {
    plan tests => 3;

    # Test without authorization header
    my $res = $test->request(GET '/api/search?q=test');
    is($res->code, 401, 'Returns 401 without auth token');

    my $data = $json->decode($res->content);
    is($data->{success}, 0, 'Success is false');
    like($data->{error}, qr/authentication/i, 'Error mentions authentication');
};

subtest 'Invalid Token' => sub {
    plan tests => 2;

    my $res = $test->request(
        GET '/api/search?q=test',
        Authorization => 'Bearer invalid_token_here'
    );
    is($res->code, 401, 'Returns 401 with invalid token');

    my $data = $json->decode($res->content);
    is($data->{success}, 0, 'Success is false');
};

# ============================================================================
# Query Validation Tests
# ============================================================================

=head2 Query Validation

Tests for input validation:
- Missing query parameter
- Empty query
- Query too short (< 2 chars)
- Query with only whitespace

=cut

SKIP: {
    skip 'Need valid auth token for validation tests', 1 unless $ENV{TEST_AUTH_TOKEN};

    my $token = $ENV{TEST_AUTH_TOKEN};

    subtest 'Query Validation' => sub {
        plan tests => 12;

        # Missing query parameter
        my $res = $test->request(
            GET '/api/search',
            Authorization => "Bearer $token"
        );
        is($res->code, 400, 'Returns 400 for missing query');
        my $data = $json->decode($res->content);
        is($data->{success}, 0, 'Success is false');
        like($data->{error}, qr/at least 2 characters/i, 'Error mentions minimum length');

        # Empty query
        $res = $test->request(
            GET '/api/search?q=',
            Authorization => "Bearer $token"
        );
        is($res->code, 400, 'Returns 400 for empty query');
        $data = $json->decode($res->content);
        is($data->{success}, 0, 'Success is false');

        # Single character query
        $res = $test->request(
            GET '/api/search?q=a',
            Authorization => "Bearer $token"
        );
        is($res->code, 400, 'Returns 400 for single character');
        $data = $json->decode($res->content);
        is($data->{success}, 0, 'Success is false');

        # Whitespace only query
        $res = $test->request(
            GET '/api/search?q=%20%20',  # URL-encoded spaces
            Authorization => "Bearer $token"
        );
        is($res->code, 400, 'Returns 400 for whitespace-only query');
        $data = $json->decode($res->content);
        is($data->{success}, 0, 'Success is false');

        # Valid 2-character query
        $res = $test->request(
            GET '/api/search?q=ab',
            Authorization => "Bearer $token"
        );
        is($res->code, 200, 'Returns 200 for 2-character query');
        $data = $json->decode($res->content);
        is($data->{success}, 1, 'Success is true');
        ok(exists $data->{data}, 'Has data field');
    };
}

# ============================================================================
# Search Functionality Tests
# ============================================================================

=head2 Search Functionality

Tests for actual search operations (requires valid test data):
- Search returns correct structure
- Search across multiple entities
- Result limits (5 per category)
- Case-insensitive search

=cut

SKIP: {
    skip 'Need valid auth token for search tests', 1 unless $ENV{TEST_AUTH_TOKEN};

    my $token = $ENV{TEST_AUTH_TOKEN};

    subtest 'Search Response Structure' => sub {
        plan tests => 10;

        my $res = $test->request(
            GET '/api/search?q=test',
            Authorization => "Bearer $token"
        );

        is($res->code, 200, 'Returns 200 for valid search');

        my $data = $json->decode($res->content);
        is($data->{success}, 1, 'Success is true');
        ok(exists $data->{data}, 'Has data field');

        # Check structure
        my $result = $data->{data};
        ok(exists $result->{tenants}, 'Has tenants array');
        ok(exists $result->{invoices}, 'Has invoices array');
        ok(exists $result->{providers}, 'Has providers array');
        ok(exists $result->{total_count}, 'Has total_count field');

        # Check arrays
        is(ref($result->{tenants}), 'ARRAY', 'Tenants is array');
        is(ref($result->{invoices}), 'ARRAY', 'Invoices is array');
        is(ref($result->{providers}), 'ARRAY', 'Providers is array');
    };

    subtest 'Result Limits' => sub {
        plan tests => 3;

        # Search for common term likely to have many results
        my $res = $test->request(
            GET '/api/search?q=a',  # Single letter after trim will fail, using 'te' instead
            Authorization => "Bearer $token"
        );

        # Use a 2+ char query
        $res = $test->request(
            GET '/api/search?q=te',
            Authorization => "Bearer $token"
        );

        my $data = $json->decode($res->content);
        my $result = $data->{data};

        # Each category should have max 5 results
        cmp_ok(scalar(@{$result->{tenants}}), '<=', 5, 'Tenants limited to 5');
        cmp_ok(scalar(@{$result->{invoices}}), '<=', 5, 'Invoices limited to 5');
        cmp_ok(scalar(@{$result->{providers}}), '<=', 5, 'Providers limited to 5');
    };

    subtest 'Tenant Result Format' => sub {
        # Search for a term likely to match tenants
        my $res = $test->request(
            GET '/api/search?q=tenant',
            Authorization => "Bearer $token"
        );

        my $data = $json->decode($res->content);
        my $tenants = $data->{data}{tenants};

        SKIP: {
            skip 'No tenants found', 6 unless @$tenants;

            my $tenant = $tenants->[0];
            ok(exists $tenant->{id}, 'Tenant has id');
            ok(exists $tenant->{name}, 'Tenant has name');
            ok(exists $tenant->{email}, 'Tenant has email');
            ok(exists $tenant->{phone}, 'Tenant has phone');
            ok(exists $tenant->{is_active}, 'Tenant has is_active');
            is($tenant->{type}, 'tenant', 'Tenant has correct type');
        }
        ok(1, 'Tenant format test completed');
    };

    subtest 'Invoice Result Format' => sub {
        # Search for a term likely to match invoices
        my $res = $test->request(
            GET '/api/search?q=inv',
            Authorization => "Bearer $token"
        );

        my $data = $json->decode($res->content);
        my $invoices = $data->{data}{invoices};

        SKIP: {
            skip 'No invoices found', 7 unless @$invoices;

            my $invoice = $invoices->[0];
            ok(exists $invoice->{id}, 'Invoice has id');
            ok(exists $invoice->{invoice_number}, 'Invoice has invoice_number');
            ok(exists $invoice->{client_name}, 'Invoice has client_name');
            ok(exists $invoice->{total_ron}, 'Invoice has total_ron');
            ok(exists $invoice->{invoice_date}, 'Invoice has invoice_date');
            ok(exists $invoice->{is_paid}, 'Invoice has is_paid');
            is($invoice->{type}, 'invoice', 'Invoice has correct type');
        }
        ok(1, 'Invoice format test completed');
    };

    subtest 'Provider Result Format' => sub {
        # Search for a term likely to match providers
        my $res = $test->request(
            GET '/api/search?q=provider',
            Authorization => "Bearer $token"
        );

        my $data = $json->decode($res->content);
        my $providers = $data->{data}{providers};

        SKIP: {
            skip 'No providers found', 6 unless @$providers;

            my $provider = $providers->[0];
            ok(exists $provider->{id}, 'Provider has id');
            ok(exists $provider->{name}, 'Provider has name');
            ok(exists $provider->{account_number}, 'Provider has account_number');
            ok(exists $provider->{provider_type}, 'Provider has provider_type');
            ok(exists $provider->{is_active}, 'Provider has is_active');
            is($provider->{type}, 'provider', 'Provider has correct type');
        }
        ok(1, 'Provider format test completed');
    };

    subtest 'Total Count Accuracy' => sub {
        plan tests => 1;

        my $res = $test->request(
            GET '/api/search?q=test',
            Authorization => "Bearer $token"
        );

        my $data = $json->decode($res->content);
        my $result = $data->{data};

        my $calculated_count =
            scalar(@{$result->{tenants}}) +
            scalar(@{$result->{invoices}}) +
            scalar(@{$result->{providers}});

        is($result->{total_count}, $calculated_count, 'Total count matches sum of results');
    };
}

# ============================================================================
# Edge Case Tests
# ============================================================================

=head2 Edge Cases

Tests for special characters and edge cases

=cut

SKIP: {
    skip 'Need valid auth token for edge case tests', 1 unless $ENV{TEST_AUTH_TOKEN};

    my $token = $ENV{TEST_AUTH_TOKEN};

    subtest 'Special Characters in Query' => sub {
        plan tests => 6;

        # Query with special characters
        my @special_queries = (
            'test@example.com',  # Email-like
            'ABC-123',           # Hyphenated
            '12345',             # Numbers only
        );

        foreach my $query (@special_queries) {
            my $res = $test->request(
                GET "/api/search?q=$query",
                Authorization => "Bearer $token"
            );
            is($res->code, 200, "Returns 200 for query: $query");

            my $data = $json->decode($res->content);
            is($data->{success}, 1, "Success for query: $query");
        }
    };

    subtest 'Empty Results' => sub {
        plan tests => 5;

        # Search for something unlikely to exist
        my $res = $test->request(
            GET '/api/search?q=xyzabc999nonexistent',
            Authorization => "Bearer $token"
        );

        is($res->code, 200, 'Returns 200 even with no results');

        my $data = $json->decode($res->content);
        is($data->{success}, 1, 'Success is true');

        my $result = $data->{data};
        is(scalar(@{$result->{tenants}}), 0, 'Tenants array is empty');
        is(scalar(@{$result->{invoices}}), 0, 'Invoices array is empty');
        is(scalar(@{$result->{providers}}), 0, 'Providers array is empty');
    };
}

done_testing();

__END__

=head1 RUNNING TESTS

To run these tests, you need a valid authentication token:

  # Get auth token first by logging in
  export TEST_AUTH_TOKEN="your_jwt_token_here"

  # Run the tests
  prove -lv t/search-api.t

Or run all tests:

  prove -lr t/

=head1 AUTHOR

Property Management System

=cut
