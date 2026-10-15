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

plan tests => 4;

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

# ---------------------------------------------------------------------------
# Electricity: billed as a standing %, but for tenants with an assigned
# electricity meter that % is the tenant meter's share of the GM-001 general
# building meter. The breakdown sheet documents that derivation.
# ---------------------------------------------------------------------------

sub general_meter {
    my $m = $schema->resultset('ElectricityMeter')->search({
        is_general => 1, is_active => 1, meter_number => 'GM-001',
    })->first;
    return $m if $m;
    return $schema->resultset('ElectricityMeter')->create({
        name => 'General Meter - Building', meter_number => 'GM-001',
        is_general => 1, is_active => 1,
    });
}

# Build an electricity fixture. Returns ($invoice, $tenant).
#   tenant_cons / general_cons -> the meter figures
#   billed_pct / billed_amount -> what we actually invoiced
sub build_electricity {
    my (%a) = @_;

    $schema->resultset('MeterReading')->delete_all;
    $schema->resultset('ElectricityMeter')->search({ is_general => 0 })->delete_all;

    my $month = $a{month};
    my $tenant = TestHelper::create_test_tenant($schema, name => $a{name});

    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id    => $tenant->id,
        utility_type => 'electricity',
        percentage   => $a{billed_pct},
        uses_meter   => 0,          # electricity is never flagged as metered
    });

    if ($a{assign_meter}) {
        my $meter = $schema->resultset('ElectricityMeter')->create({
            name => $a{name}, tenant_id => $tenant->id,
            is_general => 0, is_active => 1,
        });
        if (defined $a{tenant_cons}) {
            $schema->resultset('MeterReading')->create({
                meter_id               => $meter->id,
                reading_date           => sprintf('2026-%02d-04', $month + 1),
                previous_reading_value => $a{prev_index},
                reading_value          => $a{cur_index},
                consumption            => $a{tenant_cons},
                period_month           => $month,
                period_year            => 2026,
            });
        }
    }

    if (defined $a{general_cons}) {
        $schema->resultset('MeterReading')->create({
            meter_id               => general_meter()->id,
            reading_date           => sprintf('2026-%02d-04', $month + 1),
            previous_reading_value => 466660.00,
            reading_value          => 466660.00 + $a{general_cons},
            consumption            => $a{general_cons},
            period_month           => $month,
            period_year            => 2026,
        });
    }

    my $provider = TestHelper::create_test_provider(
        $schema, type => 'electricity', name => 'Electricity Provider'
    );
    my $rinv = $schema->resultset('ReceivedInvoice')->create({
        provider_id    => $provider->id,
        invoice_number => 'ELEC-' . $month,
        invoice_date   => sprintf('2026-%02d-10', $month + 1),
        due_date       => sprintf('2026-%02d-25', $month + 1),
        amount         => $a{invoice_amount},
        utility_type   => 'electricity',
        period_start   => sprintf('2026-%02d-01', $month),
        period_end     => sprintf('2026-%02d-28', $month),
    });

    my $calc = $schema->resultset('UtilityCalculation')->create({
        period_month => $month,
        period_year  => 2026,
    });
    $schema->resultset('UtilityCalculationDetail')->create({
        calculation_id      => $calc->id,
        tenant_id           => $tenant->id,
        utility_type        => 'electricity',
        received_invoice_id => $rinv->id,
        percentage          => $a{billed_pct},
        amount              => $a{billed_amount},
    });

    my $invoice = $schema->resultset('Invoice')->create({
        invoice_number => 'ARC TEST-EL-' . $month,
        invoice_type   => 'utility',
        tenant_id      => $tenant->id,
        invoice_date   => sprintf('2026-%02d-15', $month + 1),
        due_date       => sprintf('2026-%02d-30', $month + 1),
        calculation_id => $calc->id,
        subtotal_ron   => $a{billed_amount},
        vat_amount     => 0,
        total_ron      => $a{billed_amount},
    });

    return ($invoice, $tenant);
}

sub pdfgen {
    return PropertyManager::Services::PDFGenerator->new(
        schema => $schema, config => { app => {} },
    );
}

# Real figures from the Caferamica August 2026 invoice: 875 kWh of the general
# building meter's 2418 kWh is 36.1869%, stored as 36.19%, and 36.19% of
# 3860.88 RON is the 1397.25 RON we invoiced.
subtest 'electricity breakdown derives the billed % from the tenant and GM-001 meters' => sub {
    plan tests => 12;

    my ($invoice) = build_electricity(
        name => 'Caferamica', month => 8, assign_meter => 1,
        prev_index => 159.00, cur_index => 1034.00, tenant_cons => 875.00,
        general_cons => 2418.00,
        invoice_amount => 3860.88, billed_pct => 36.19, billed_amount => 1397.25,
    );

    my $vars = pdfgen()->build_invoice_template_vars($invoice->id);

    is(scalar @{$vars->{metered_breakdown}}, 1, 'one breakdown entry');

    my $item = $vars->{metered_breakdown}[0];
    is($item->{utility_type},      'electricity', 'utility_type is electricity');
    is($item->{previous_index},    '159.00',      'previous_index formatted');
    is($item->{current_index},     '1034.00',     'current_index formatted');
    is($item->{tenant_units},      '875.00',      'tenant consumption formatted');
    is($item->{general_units},     '2418.00',     'general building consumption formatted');
    is($item->{general_meter_name}, 'General Meter - Building', 'names the general meter used');
    is($item->{ratio_pct},         '36.19',       'ratio derived from the two meters');
    is($item->{effective_pct},     '36.19',       'billed percentage from the invoiced detail');
    is($item->{invoice_amount},    '3860.88',     'supplier invoice amount formatted');
    is($item->{tenant_amount},     '1397.25',     'invoiced amount formatted');
    ok($item->{derivation_ok}, 'derivation reconciles with what we billed');
};

subtest 'electricity breakdown is skipped when no meter is assigned to the tenant' => sub {
    plan tests => 1;

    my ($invoice) = build_electricity(
        name => 'No Meter Tenant', month => 7, assign_meter => 0,
        general_cons => 1590.00,
        invoice_amount => 2539.06, billed_pct => 8.62, billed_amount => 218.87,
    );

    my $vars = pdfgen()->build_invoice_template_vars($invoice->id);

    is(scalar @{$vars->{metered_breakdown}}, 0, 'no breakdown entry without an assigned meter');
};

# The 2026-05 bootstrap case: the meter was just installed, so its reading does
# not reproduce the percentage we billed. Print the readings, flag the
# derivation as unusable so the sheet never shows contradictory arithmetic.
subtest 'electricity breakdown flags a derivation that disagrees with the billed %' => sub {
    plan tests => 4;

    my ($invoice) = build_electricity(
        name => 'Bootstrap Tenant', month => 5, assign_meter => 1,
        prev_index => undef, cur_index => 5.00, tenant_cons => 0.00,
        general_cons => 1274.00,
        invoice_amount => 2067.67, billed_pct => 0.63, billed_amount => 13.03,
    );

    my $vars = pdfgen()->build_invoice_template_vars($invoice->id);

    is(scalar @{$vars->{metered_breakdown}}, 1, 'entry still rendered');

    my $item = $vars->{metered_breakdown}[0];
    is($item->{ratio_pct},     '0.00',  'derived ratio is zero for the bootstrap reading');
    is($item->{effective_pct}, '0.63',  'billed percentage is preserved');
    ok(!$item->{derivation_ok}, 'derivation flagged as not reconciling');
};
