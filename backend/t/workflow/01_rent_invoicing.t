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

plan tests => 1;

# ============================================================================
# Complete Rent Invoicing Workflow
# ============================================================================

subtest 'Complete rent invoicing workflow' => sub {
    plan tests => 17;

    # Step 1: Verify or create company
    my $company_res = TestHelper::auth_get($test, '/api/company');
    my $company_data = TestHelper::decode_response($company_res);

    unless ($company_data->{data}{company}) {
        my $create_company = TestHelper::auth_post($test, '/api/company', {
            name => 'Workflow Test Company SRL',
            cui_cif => 'RO12345678',
            address => '123 Test St',
            city => 'Bucharest',
            county => 'Bucharest',
        });
        ok($create_company->is_success, 'Company created');
    } else {
        ok(1, 'Company exists');
    }

    # Step 2: Create tenant with rent amount
    my $tenant_res = TestHelper::auth_post($test, '/api/tenants', {
        name => 'Workflow Test Tenant',
        address => '456 Tenant Ave',
        city => 'Bucharest',
        county => 'Bucharest',
        email => 'workflow@test.com',
        phone => '0721234567',
        rent_amount_eur => 600.00,
        contract_start => '2025-01-01',
        is_active => 1,
    });

    is($tenant_res->code, 200, 'Step 2: Tenant created');
    my $tenant_data = TestHelper::decode_response($tenant_res);
    my $tenant_id = $tenant_data->{data}{tenant}{id};
    ok($tenant_id, 'Tenant ID obtained');

    # Step 3: Fetch BNR exchange rate
    my $rate_res = TestHelper::auth_get($test, '/api/exchange-rates/current');
    my $rate_data = TestHelper::decode_response($rate_res);

    # If no rate, cache one for testing
    unless ($rate_data->{success} && $rate_data->{data}{rate}) {
        TestHelper::create_test_exchange_rate($schema);
        $rate_res = TestHelper::auth_get($test, '/api/exchange-rates/current');
        $rate_data = TestHelper::decode_response($rate_res);
    }

    ok($rate_data->{data}{rate}, 'Step 3: Exchange rate available');
    my $exchange_rate = $rate_data->{data}{rate};
    ok($exchange_rate > 0, 'Exchange rate is positive');

    # Step 4: Generate rent invoice
    my $invoice_res = TestHelper::auth_post($test, '/api/invoices/rent', {
        tenant_id => $tenant_id,
        invoice_date => '2025-12-09',
        due_date => '2025-12-31',
        notes => 'December 2025 rent',
    });

    is($invoice_res->code, 200, 'Step 4: Rent invoice created');
    my $invoice_data = TestHelper::decode_response($invoice_res);
    my $invoice_id = $invoice_data->{data}{invoice}{id};
    ok($invoice_id, 'Invoice ID obtained');
    like($invoice_data->{data}{invoice}{invoice_number}, qr/^ARC/, 'Invoice number generated');

    # Step 5: Add additional line item
    my $item_res = TestHelper::auth_post($test, "/api/invoices/$invoice_id/items", {
        description => 'Maintenance fee',
        quantity => 1,
        unit_price => 50.00,
        vat_rate => 0,
    });

    is($item_res->code, 200, 'Step 5: Additional item added');

    # Step 6: Verify totals
    my $get_invoice_res = TestHelper::auth_get($test, "/api/invoices/$invoice_id");
    my $get_invoice_data = TestHelper::decode_response($get_invoice_res);

    my $invoice = $get_invoice_data->{data}{invoice};
    # Use numeric comparison with tolerance for floating point
    ok(abs($invoice->{subtotal_eur} - 600.00) < 0.01, 'Step 6: Subtotal EUR correct (rent only)');

    # Rent in RON + maintenance
    my $expected_ron = (600.00 * $exchange_rate) + 50.00;
    ok(abs($invoice->{subtotal_ron} - $expected_ron) < 0.01, 'Subtotal RON includes additional item');

    my @items = @{$invoice->{items}};
    is(scalar @items, 2, 'Two items: rent + maintenance');

    # Step 7: Generate PDF
    my $pdf_res = TestHelper::auth_get($test, "/api/invoices/$invoice_id/pdf");

    is($pdf_res->code, 200, 'Step 7: PDF generated');
    is($pdf_res->header('Content-Type'), 'application/pdf', 'PDF content type correct');
    ok(length($pdf_res->content) > 1000, 'PDF has content');

    # Step 8: Mark as paid
    my $paid_res = TestHelper::auth_post($test, "/api/invoices/$invoice_id/mark-paid", {
        paid_date => '2025-12-15',
    });

    is($paid_res->code, 200, 'Step 8: Invoice marked as paid');

    # Verify paid status
    my $final_res = TestHelper::auth_get($test, "/api/invoices/$invoice_id");
    my $final_data = TestHelper::decode_response($final_res);

    is($final_data->{data}{invoice}{is_paid}, 1, 'Invoice is paid');

    note("Workflow completed successfully:");
    note("  - Company: " . ($company_data->{data}{company}{name} || 'Created'));
    note("  - Tenant: Workflow Test Tenant (ID: $tenant_id)");
    note("  - Exchange Rate: $exchange_rate EUR/RON");
    note("  - Invoice: " . $invoice_data->{data}{invoice}{invoice_number});
    note("  - Total: " . $invoice->{subtotal_ron} . " RON");
};

TestHelper::cleanup_test_data($schema);
done_testing();
