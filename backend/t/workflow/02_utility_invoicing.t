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
# Complete Utility Invoicing Workflow
# ============================================================================

subtest 'Complete utility invoicing workflow' => sub {
    plan tests => 19;

    # Step 1: Create tenant with utility percentages
    my $tenant_res = TestHelper::auth_post($test, '/api/tenants', {
        name => 'Utility Workflow Tenant',
        address => '789 Utility St',
        city => 'Bucharest',
        county => 'Bucharest',
        email => 'utility@test.com',
        phone => '0721234568',
        rent_amount_eur => 500.00,
        is_active => 1,
    });

    is($tenant_res->code, 200, 'Step 1: Tenant created');
    my $tenant_data = TestHelper::decode_response($tenant_res);
    my $tenant_id = $tenant_data->{data}{tenant}{id};

    # Set utility percentages
    my $pct_res = TestHelper::auth_put($test, "/api/tenants/$tenant_id/percentages", {
        percentages => {
            electricity => 40.00,
            gas => 35.00,
            water => 30.00,
        },
    });

    is($pct_res->code, 200, 'Utility percentages set');

    # Step 2: Create utility providers
    my $elec_provider_res = TestHelper::auth_post($test, '/api/utility-providers', {
        name => 'Electric Company',
        type => 'electricity',
        account_number => 'ELEC123',
    });

    is($elec_provider_res->code, 200, 'Step 2: Electricity provider created');
    my $elec_provider_data = TestHelper::decode_response($elec_provider_res);
    my $elec_provider_id = $elec_provider_data->{data}{provider}{id};

    # Step 3: Record received invoices for period
    my $received_inv_res = TestHelper::auth_post($test, '/api/received-invoices', {
        provider_id => $elec_provider_id,
        invoice_number => 'INV-DEC-001',
        invoice_date => '2025-12-01',
        due_date => '2025-12-15',
        amount => 1000.00,
        utility_type => 'electricity',
        period_start => '2025-11-01',
        period_end => '2025-11-30',
    });

    is($received_inv_res->code, 200, 'Step 3: Received invoice created');
    my $received_inv_data = TestHelper::decode_response($received_inv_res);
    ok($received_inv_data->{data}{invoice}{id}, 'Received invoice ID obtained');

    # Step 4: Record meter readings
    my $general_meter = $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first;
    unless ($general_meter) {
        $general_meter = $schema->resultset('ElectricityMeter')->create({
            name => 'General',
            is_general => 1,
            is_active => 1,
        });
    }

    my $reading_res = TestHelper::auth_post($test, '/api/meter-readings', {
        meter_id => $general_meter->id,
        reading_date => '2025-11-30',
        reading_value => 15000.00,
        consumption => 1000.00,
        period_month => 11,
        period_year => 2025,
    });

    # Reading might already exist, so accept 200 or 400
    ok($reading_res->code == 200 || $reading_res->code == 400, 'Step 4: Meter reading recorded or exists');

    # Step 5: Calculate utility shares (preview)
    my $preview_res = TestHelper::auth_get($test, '/api/utility-calculations/preview/2025/11');

    is($preview_res->code, 200, 'Step 5: Utility calculation previewed');
    my $preview_data = TestHelper::decode_response($preview_res);

    ok($preview_data->{data}{calculation}, 'Calculation data present');
    my @tenant_shares = @{$preview_data->{data}{calculation}{tenant_shares}};
    ok(scalar @tenant_shares > 0, 'Tenant shares calculated');

    my ($tenant_share) = grep { $_->{tenant_id} == $tenant_id } @tenant_shares;
    ok($tenant_share, 'Our tenant has shares');

    # Step 6: Override one percentage (optional)
    # Skipping for simplicity

    # Step 7: Save calculation
    my $calc_res = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_month => 11,
        period_year => 2025,
    });

    is($calc_res->code, 200, 'Step 7: Calculation saved');
    my $calc_data = TestHelper::decode_response($calc_res);
    my $calculation_id = $calc_data->{data}{calculation}{id};
    ok($calculation_id, 'Calculation ID obtained');

    # Step 8: Generate utility invoice for tenant
    my $utility_inv_res = TestHelper::auth_post($test, '/api/invoices/utility', {
        tenant_id => $tenant_id,
        calculation_id => $calculation_id,
        invoice_date => '2025-12-05',
        due_date => '2025-12-20',
    });

    is($utility_inv_res->code, 200, 'Step 8: Utility invoice generated');
    my $utility_inv_data = TestHelper::decode_response($utility_inv_res);
    my $invoice_id = $utility_inv_data->{data}{invoice}{id};
    ok($invoice_id, 'Utility invoice ID obtained');

    # Step 9: Verify amounts match calculation
    my $get_inv_res = TestHelper::auth_get($test, "/api/invoices/$invoice_id");
    my $get_inv_data = TestHelper::decode_response($get_inv_res);

    my $invoice = $get_inv_data->{data}{invoice};
    is($invoice->{invoice_type}, 'utility', 'Invoice type is utility');
    is($invoice->{calculation_id}, $calculation_id, 'Linked to calculation');

    # Tenant's share should be 40% of 1000 = 400 RON
    my $expected_amount = 400.00;  # 40% of electricity
    ok($invoice->{subtotal_ron} >= $expected_amount * 0.9 &&
       $invoice->{subtotal_ron} <= $expected_amount * 1.1,
       'Invoice amount approximately matches expected share');

    # Step 10: Generate PDF
    my $pdf_res = TestHelper::auth_get($test, "/api/invoices/$invoice_id/pdf");

    is($pdf_res->code, 200, 'Step 10: PDF generated');
    ok(length($pdf_res->content) > 1000, 'PDF has content');

    note("Utility workflow completed successfully:");
    note("  - Tenant: Utility Workflow Tenant (40% elec, 35% gas, 30% water)");
    note("  - Received Invoice: 1000 RON electricity");
    note("  - Calculation ID: $calculation_id");
    note("  - Utility Invoice: " . $invoice->{invoice_number});
    note("  - Tenant Share: " . $invoice->{subtotal_ron} . " RON");
};

TestHelper::cleanup_test_data($schema);
done_testing();
