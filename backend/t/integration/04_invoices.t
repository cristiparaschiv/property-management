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

# Setup test data
my $company = TestHelper::create_test_company($schema);
my $tenant = TestHelper::create_test_tenant($schema, rent_amount_eur => 500.00);
TestHelper::create_test_exchange_rate($schema, rate_date => '2025-12-09', eur_ron => 4.9750);

plan tests => 7;

# ============================================================================
# Test: GET /api/invoices/next-number - get next invoice number
# ============================================================================

subtest 'GET /api/invoices/next-number' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_get($test, '/api/invoices/next-number');

    is($res->code, 200, 'Status 200 OK');
    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    like($data->{data}{next_number}, qr/^ARC\d{5}$/, 'Invoice number format correct');
};

# ============================================================================
# Test: POST /api/invoices/rent - create rent invoice
# ============================================================================

subtest 'POST /api/invoices/rent - create rent invoice' => sub {
    plan tests => 9;

    my $invoice_data = {
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
        due_date => '2025-12-31',
        notes => 'December rent',
    };

    my $res = TestHelper::auth_post($test, '/api/invoices/rent', $invoice_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    ok($data->{data}{invoice}, 'Invoice data present');
    like($data->{data}{invoice}{invoice_number}, qr/^ARC/, 'Invoice number assigned');
    is($data->{data}{invoice}{invoice_type}, 'rent', 'Type is rent');
    is($data->{data}{invoice}{tenant_id}, $tenant->id, 'Tenant ID correct');
    ok(abs($data->{data}{invoice}{exchange_rate} - 4.9750) < 0.001, 'Exchange rate applied');
    ok(abs($data->{data}{invoice}{subtotal_eur} - 500.00) < 0.01, 'Subtotal EUR correct');
    ok(abs($data->{data}{invoice}{subtotal_ron} - 2487.50) < 0.01, 'Subtotal RON calculated');

    $test->{invoice_id} = $data->{data}{invoice}{id};
};

# ============================================================================
# Test: GET /api/invoices/:id - get invoice
# ============================================================================

subtest 'GET /api/invoices/:id - retrieve invoice' => sub {
    plan tests => 5;

    my $invoice_id = $test->{invoice_id};
    my $res = TestHelper::auth_get($test, "/api/invoices/$invoice_id");

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    is($data->{data}{invoice}{id}, $invoice_id, 'Invoice ID matches');
    ok(ref $data->{data}{invoice}{items} eq 'ARRAY', 'Items array included');
    ok($data->{data}{invoice}{tenant}, 'Tenant info included');
};

# ============================================================================
# Test: POST /api/invoices/:id/items - add invoice item
# ============================================================================

subtest 'POST /api/invoices/:id/items - add item to invoice' => sub {
    plan tests => 5;

    my $invoice_id = $test->{invoice_id};
    my $item_data = {
        description => 'Parking fee',
        quantity => 1,
        unit_price => 100.00,
        vat_rate => 0,
    };

    my $res = TestHelper::auth_post($test, "/api/invoices/$invoice_id/items", $item_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    ok($data->{data}{item}, 'Item data present');
    is($data->{data}{item}{description}, 'Parking fee', 'Description matches');
    is($data->{data}{item}{total}, 100.00, 'Total calculated');
};

# ============================================================================
# Test: GET /api/invoices - list invoices with filters
# ============================================================================

subtest 'GET /api/invoices - list and filter invoices' => sub {
    plan tests => 5;

    # List all
    my $res = TestHelper::auth_get($test, '/api/invoices');
    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    ok(ref $data->{data}{invoices} eq 'ARRAY', 'Invoices array');

    # Filter by tenant
    my $filtered_res = TestHelper::auth_get($test, "/api/invoices?tenant_id=" . $tenant->id);
    is($filtered_res->code, 200, 'Filtered request OK');

    my $filtered_data = TestHelper::decode_response($filtered_res);
    ok(scalar @{$filtered_data->{data}{invoices}} > 0, 'Filtered results returned');
};

# ============================================================================
# Test: POST /api/invoices/:id/mark-paid - mark invoice as paid
# ============================================================================

subtest 'POST /api/invoices/:id/mark-paid' => sub {
    plan tests => 4;

    my $invoice_id = $test->{invoice_id};
    my $paid_data = {
        paid_date => '2025-12-15',
    };

    my $res = TestHelper::auth_post($test, "/api/invoices/$invoice_id/mark-paid", $paid_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');

    # Verify invoice is marked paid
    my $get_res = TestHelper::auth_get($test, "/api/invoices/$invoice_id");
    my $get_data = TestHelper::decode_response($get_res);

    is($get_data->{data}{invoice}{is_paid}, 1, 'Invoice marked as paid');
    is($get_data->{data}{invoice}{paid_date}, '2025-12-15', 'Paid date set');
};

# ============================================================================
# Test: GET /api/invoices/:id/pdf - download PDF
# ============================================================================

subtest 'GET /api/invoices/:id/pdf - download invoice PDF' => sub {
    plan tests => 3;

    my $invoice_id = $test->{invoice_id};
    my $res = TestHelper::auth_get($test, "/api/invoices/$invoice_id/pdf");

    is($res->code, 200, 'Status 200 OK');
    is($res->header('Content-Type'), 'application/pdf', 'Content-Type is PDF');
    ok(length($res->content) > 1000, 'PDF has content');
};

TestHelper::cleanup_test_data($schema);
done_testing();
