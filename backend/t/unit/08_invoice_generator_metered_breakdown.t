#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::PDFGenerator;

my $schema = TestHelper::schema();
TestHelper::cleanup_test_data($schema);
TestHelper::create_test_company($schema);

# Also wipe metered-billing-specific tables used here
$schema->resultset('MeteredCalculationInput')->delete_all;
$schema->resultset('GasReading')->delete_all;
$schema->resultset('WaterReading')->delete_all;

plan tests => 1;

subtest 'build_invoice_template_vars includes metered_breakdown for gas meter tenant' => sub {
    plan tests => 8;

    # --- fixtures ---
    my $tenant = TestHelper::create_test_tenant($schema, name => 'Metered Tenant');

    # Tenant uses meter for gas
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id    => $tenant->id,
        utility_type => 'gas',
        percentage   => 0,
        uses_meter   => 1,
    });

    # Gas provider + received invoice
    my $provider = TestHelper::create_test_provider(
        $schema, type => 'gas', name => 'Gas Provider'
    );
    my $rinv = $schema->resultset('ReceivedInvoice')->create({
        provider_id    => $provider->id,
        invoice_number => 'GAS-001',
        invoice_date   => '2025-11-30',
        due_date       => '2025-12-15',
        amount         => 200.00,
        utility_type   => 'gas',
        period_start   => '2025-11-01',
        period_end     => '2025-11-30',
    });

    # Utility calculation + detail + metered input
    my $calc = $schema->resultset('UtilityCalculation')->create({
        period_month => 11,
        period_year  => 2025,
    });
    my $detail = $schema->resultset('UtilityCalculationDetail')->create({
        calculation_id      => $calc->id,
        tenant_id           => $tenant->id,
        utility_type        => 'gas',
        received_invoice_id => $rinv->id,
        percentage          => 25.00,
        amount              => 50.00,
    });
    $schema->resultset('MeteredCalculationInput')->create({
        calculation_id      => $calc->id,
        received_invoice_id => $rinv->id,
        utility_type        => 'gas',
        total_units         => 40.00,
    });
    $schema->resultset('GasReading')->create({
        tenant_id              => $tenant->id,
        reading_date           => '2025-11-30',
        reading_value          => 1010.00,
        previous_reading_value => 1000.00,
        consumption            => 10.00,
        period_month           => 11,
        period_year            => 2025,
    });

    # Invoice referencing the calculation
    my $invoice = $schema->resultset('Invoice')->create({
        invoice_number => 'ARC TEST-BD-1',
        invoice_type   => 'utility',
        tenant_id      => $tenant->id,
        invoice_date   => '2025-12-01',
        due_date       => '2025-12-15',
        calculation_id => $calc->id,
        subtotal_ron   => 50.00,
        vat_amount     => 0,
        total_ron      => 50.00,
    });

    # --- exercise ---
    my $pdfgen = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => { app => {} },
    );

    my $vars = $pdfgen->build_invoice_template_vars($invoice->id);

    ok($vars, 'vars returned');
    is(ref $vars->{metered_breakdown}, 'ARRAY', 'metered_breakdown is an arrayref');
    is(scalar @{$vars->{metered_breakdown}}, 1, 'one metered entry');

    my $item = $vars->{metered_breakdown}[0];
    is($item->{utility_type},   'gas',     'utility_type is gas');
    is($item->{previous_index}, '1000.00', 'previous_index formatted');
    is($item->{current_index},  '1010.00', 'current_index formatted');
    is($item->{total_units},    '40.00',   'total_units formatted');
    is($item->{tenant_amount},  '50.00',   'tenant_amount formatted');
};
