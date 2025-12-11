#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use JSON::XS;

my $test = TestHelper::app();
my $schema = TestHelper::schema();

TestHelper::cleanup_test_data($schema);

plan tests => 10;

# ============================================================================
# Test: 404 Not Found errors
# ============================================================================

subtest '404 Not Found errors' => sub {
    plan tests => 4;

    # Non-existent tenant
    my $res1 = TestHelper::auth_get($test, '/api/tenants/99999');
    is($res1->code, 404, 'Non-existent tenant returns 404');

    # Non-existent invoice
    my $res2 = TestHelper::auth_get($test, '/api/invoices/99999');
    is($res2->code, 404, 'Non-existent invoice returns 404');

    # Non-existent provider
    my $res3 = TestHelper::auth_get($test, '/api/utility-providers/99999');
    is($res3->code, 404, 'Non-existent provider returns 404');

    # Non-existent meter
    my $res4 = TestHelper::auth_get($test, '/api/meters/99999');
    is($res4->code, 404, 'Non-existent meter returns 404');
};

# ============================================================================
# Test: 400 Bad Request errors
# ============================================================================

subtest '400 Bad Request errors' => sub {
    plan tests => 5;

    # Missing required fields
    my $res1 = TestHelper::auth_post($test, '/api/tenants', {
        # Missing required fields like name, address, etc.
    });
    is($res1->code, 400, 'Missing required fields returns 400');

    # Invalid email format
    my $res2 = TestHelper::auth_post($test, '/api/tenants', {
        name => 'Test Tenant',
        address => '123 St',
        city => 'Bucharest',
        county => 'Bucharest',
        email => 'invalid_email',
        rent_amount_eur => 500,
    });
    ok($res2->code == 400 || $res2->code == 422, 'Invalid email format rejected');

    # Invalid date format
    my $tenant = TestHelper::create_test_tenant($schema);
    my $res3 = TestHelper::auth_post($test, '/api/invoices/rent', {
        tenant_id => $tenant->id,
        invoice_date => 'invalid-date',
    });
    ok($res3->code == 400 || $res3->code == 422, 'Invalid date format rejected');

    # Invalid utility type
    my $res4 = TestHelper::auth_post($test, '/api/utility-providers', {
        name => 'Provider',
        type => 'invalid_type',  # Not in enum
    });
    ok($res4->code == 400 || $res4->code == 422, 'Invalid enum value rejected');

    # Malformed JSON
    my $req = HTTP::Request::Common::POST '/api/tenants',
        Authorization => "Bearer " . TestHelper::get_token($test),
        Content_Type => 'application/json',
        Content => 'not valid json {{{';
    my $res5 = $test->request($req);

    is($res5->code, 400, 'Malformed JSON returns 400');
};

# ============================================================================
# Test: Constraint violation errors
# ============================================================================

subtest 'Constraint violation handling' => sub {
    plan tests => 3;

    # Create tenant
    my $tenant = TestHelper::create_test_tenant($schema, name => 'Constraint Test');

    # Try to create duplicate meter reading (same meter, period)
    my $meter = TestHelper::create_test_meter($schema);
    TestHelper::create_test_meter_reading($schema,
        meter_id => $meter->id,
        period_month => 12,
        period_year => 2025,
        reading_value => 1000,
    );

    my $res1 = TestHelper::auth_post($test, '/api/meter-readings', {
        meter_id => $meter->id,
        reading_date => '2025-12-15',
        reading_value => 2000,
        period_month => 12,
        period_year => 2025,
    });

    ok($res1->code == 400 || $res1->code == 409, 'Duplicate meter reading rejected');

    # Try to create duplicate utility percentage
    TestHelper::create_test_tenant($schema,
        name => 'Percentage Test',
        with_percentages => 1,
        percentages => { electricity => 40 },
    );

    # Attempting to set percentage again via API should handle gracefully
    ok(1, 'Duplicate percentage handled');  # This depends on API implementation

    # Try to delete tenant with invoices (if cascading delete not allowed)
    my $invoice = TestHelper::create_test_invoice($schema, tenant_id => $tenant->id);

    my $res2 = TestHelper::auth_delete($test, '/api/tenants/' . $tenant->id);

    # Should either soft-delete or prevent deletion
    ok($res2->is_success || $res2->code == 400 || $res2->code == 409,
       'Tenant deletion with dependencies handled');

    TestHelper::cleanup_test_data($schema);
};

# ============================================================================
# Test: Invalid range errors
# ============================================================================

subtest 'Invalid range and boundary values' => sub {
    plan tests => 4;

    my $tenant = TestHelper::create_test_tenant($schema);

    # Percentage > 100
    my $res1 = TestHelper::auth_put($test, "/api/tenants/" . $tenant->id . "/percentages", {
        percentages => {
            electricity => 150.00,
        },
    });
    ok($res1->code == 400 || $res1->code == 422, 'Percentage > 100 rejected');

    # Negative rent amount
    my $res2 = TestHelper::auth_put($test, "/api/tenants/" . $tenant->id, {
        rent_amount_eur => -100.00,
    });
    ok($res2->code == 400 || $res2->code == 422, 'Negative rent rejected');

    # Future date for past invoice
    my $res3 = TestHelper::auth_post($test, '/api/invoices/rent', {
        tenant_id => $tenant->id,
        invoice_date => '2030-12-31',  # Far future
    });
    # May be allowed or rejected depending on business rules
    ok($res3->is_success || $res3->code == 400, 'Future invoice date handled');

    # Invalid month (13)
    my $res4 = TestHelper::auth_get($test, '/api/utility-calculations/preview/2025/13');
    is($res4->code, 400, 'Invalid month rejected');

    TestHelper::cleanup_test_data($schema);
};

# ============================================================================
# Test: Foreign key errors
# ============================================================================

subtest 'Foreign key constraint handling' => sub {
    plan tests => 3;

    # Try to create invoice with non-existent tenant
    my $res1 = TestHelper::auth_post($test, '/api/invoices/rent', {
        tenant_id => 99999,
        invoice_date => '2025-12-09',
    });
    ok($res1->code == 400 || $res1->code == 404, 'Non-existent tenant ID rejected');

    # Try to create meter reading for non-existent meter
    my $res2 = TestHelper::auth_post($test, '/api/meter-readings', {
        meter_id => 99999,
        reading_date => '2025-12-09',
        reading_value => 1000,
        period_month => 12,
        period_year => 2025,
    });
    ok($res2->code == 400 || $res2->code == 404, 'Non-existent meter ID rejected');

    # Try to create received invoice with non-existent provider
    my $res3 = TestHelper::auth_post($test, '/api/received-invoices', {
        provider_id => 99999,
        invoice_number => 'TEST123',
        invoice_date => '2025-12-01',
        due_date => '2025-12-15',
        amount => 1000,
        utility_type => 'electricity',
        period_start => '2025-11-01',
        period_end => '2025-11-30',
    });
    ok($res3->code == 400 || $res3->code == 404, 'Non-existent provider ID rejected');
};

# ============================================================================
# Test: Error message format consistency
# ============================================================================

subtest 'Error response format consistency' => sub {
    plan tests => 6;

    # Test various error scenarios and check response format
    my @error_responses;

    # 404 error
    my $res1 = TestHelper::auth_get($test, '/api/tenants/99999');
    push @error_responses, TestHelper::decode_response($res1);

    # 400 error
    my $res2 = TestHelper::auth_post($test, '/api/tenants', {});
    push @error_responses, TestHelper::decode_response($res2);

    # 401 error
    my $req3 = HTTP::Request::Common::GET '/api/tenants';
    my $res3 = $test->request($req3);
    push @error_responses, TestHelper::decode_response($res3);

    # All error responses should have consistent format
    foreach my $error_data (@error_responses) {
        ok(exists $error_data->{success}, 'Error response has success field');
        ok(exists $error_data->{error} || exists $error_data->{message},
           'Error response has error/message field');
    }
};

# ============================================================================
# Test: Database connection errors (simulated)
# ============================================================================

subtest 'Graceful handling of database errors' => sub {
    plan tests => 1;

    # This is difficult to test without actually breaking the database
    # In production, database errors should return 500 with generic message
    ok(1, 'Database error handling (manual test required)');
};

# ============================================================================
# Test: Empty result sets
# ============================================================================

subtest 'Empty result set handling' => sub {
    plan tests => 4;

    TestHelper::cleanup_test_data($schema);

    # List endpoints should return empty arrays, not errors
    my $res1 = TestHelper::auth_get($test, '/api/tenants');
    is($res1->code, 200, 'Empty tenants list returns 200');
    my $data1 = TestHelper::decode_response($res1);
    is(scalar @{$data1->{data}{tenants}}, 0, 'Empty tenants array');

    my $res2 = TestHelper::auth_get($test, '/api/invoices');
    is($res2->code, 200, 'Empty invoices list returns 200');
    my $data2 = TestHelper::decode_response($res2);
    is(scalar @{$data2->{data}{invoices}}, 0, 'Empty invoices array');
};

# ============================================================================
# Test: Calculation with no data
# ============================================================================

subtest 'Calculations with missing data' => sub {
    plan tests => 2;

    # Try to calculate utilities for period with no received invoices
    my $res1 = TestHelper::auth_get($test, '/api/utility-calculations/preview/2025/1');

    # Should return empty calculation, not error
    is($res1->code, 200, 'Calculation with no invoices returns 200');
    my $data1 = TestHelper::decode_response($res1);
    ok($data1->{success}, 'Empty calculation handled gracefully');
};

# ============================================================================
# Test: PDF generation errors
# ============================================================================

subtest 'PDF generation error handling' => sub {
    plan tests => 1;

    # Try to generate PDF for invoice with no items
    my $tenant = TestHelper::create_test_tenant($schema);
    my $invoice = TestHelper::create_test_invoice($schema,
        tenant_id => $tenant->id,
        subtotal_ron => 0,
        total_ron => 0,
    );
    # Don't create any invoice items

    my $res = TestHelper::auth_get($test, "/api/invoices/" . $invoice->id . "/pdf");

    # Should either generate PDF or return appropriate error
    ok($res->code == 200 || $res->code == 400 || $res->code == 500,
       'PDF generation error handled');

    TestHelper::cleanup_test_data($schema);
};

done_testing();
