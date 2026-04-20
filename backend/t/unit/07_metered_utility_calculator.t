#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::UtilityCalculator;

my $schema = TestHelper::schema();

# ============================================================================
# Fixture builder
# ============================================================================
#
# For every subtest we rebuild the same world:
#   - Two tenants:
#       Tenant A: fixed% gas=15, fixed% water=10 (uses_meter=0 for both)
#       Tenant B: gas uses_meter=1 (percentage irrelevant),
#                 water uses_meter=1, percentage=5 (rain %)
#   - Received invoices for 2026-04: gas 300.00, water 200.00
#   - UtilityCalculation row for 2026-04
#   - MeteredCalculationInput rows:
#       gas: total_units=100, consumption_amount=NULL, rain_amount=NULL
#       water: total_units=80, consumption_amount=160, rain_amount=40
#   - GasReading Tenant B 2026-04: 200 -> 220 (consumption 20)
#   - WaterReading Tenant B 2026-04: 500 -> 520 (consumption 20)

sub build_fixtures {
    # Wipe everything related
    $schema->resultset('UtilityCalculationDetail')->delete_all;
    $schema->resultset('MeteredCalculationInput')->delete_all;
    $schema->resultset('UtilityCalculation')->delete_all;
    $schema->resultset('GasReading')->delete_all;
    $schema->resultset('WaterReading')->delete_all;
    $schema->resultset('ReceivedInvoice')->delete_all;
    $schema->resultset('UtilityProvider')->delete_all;
    $schema->resultset('TenantUtilityPercentage')->delete_all;
    $schema->resultset('Tenant')->delete_all;

    my $tenant_a = TestHelper::create_test_tenant(
        $schema,
        name => 'Metered Tenant A (fixed)',
    );
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id    => $tenant_a->id,
        utility_type => 'gas',
        percentage   => 15.00,
        uses_meter   => 0,
    });
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id    => $tenant_a->id,
        utility_type => 'water',
        percentage   => 10.00,
        uses_meter   => 0,
    });

    my $tenant_b = TestHelper::create_test_tenant(
        $schema,
        name => 'Metered Tenant B',
    );
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id    => $tenant_b->id,
        utility_type => 'gas',
        percentage   => 0.00,
        uses_meter   => 1,
    });
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id    => $tenant_b->id,
        utility_type => 'water',
        percentage   => 5.00,   # reinterpreted as "rain water fixed %"
        uses_meter   => 1,
    });

    my $gas_invoice = TestHelper::create_test_received_invoice(
        $schema,
        utility_type => 'gas',
        period_start => '2026-04-01',
        period_end   => '2026-04-30',
        invoice_date => '2026-04-30',
        due_date     => '2026-05-15',
        amount       => 300.00,
    );

    my $water_invoice = TestHelper::create_test_received_invoice(
        $schema,
        utility_type => 'water',
        period_start => '2026-04-01',
        period_end   => '2026-04-30',
        invoice_date => '2026-04-30',
        due_date     => '2026-05-15',
        amount       => 200.00,
    );

    my $calc = $schema->resultset('UtilityCalculation')->create({
        period_year  => 2026,
        period_month => 4,
        is_finalized => 0,
    });

    $schema->resultset('MeteredCalculationInput')->create({
        calculation_id      => $calc->id,
        received_invoice_id => $gas_invoice->id,
        utility_type        => 'gas',
        total_units         => 100.00,
        consumption_amount  => undef,
        rain_amount         => undef,
    });

    $schema->resultset('MeteredCalculationInput')->create({
        calculation_id      => $calc->id,
        received_invoice_id => $water_invoice->id,
        utility_type        => 'water',
        total_units         => 80.00,
        consumption_amount  => 160.00,
        rain_amount         => 40.00,
    });

    $schema->resultset('GasReading')->create({
        tenant_id              => $tenant_b->id,
        reading_date           => '2026-04-30',
        reading_value          => 220.00,
        previous_reading_value => 200.00,
        consumption            => 20.00,
        period_month           => 4,
        period_year            => 2026,
    });

    $schema->resultset('WaterReading')->create({
        tenant_id              => $tenant_b->id,
        reading_date           => '2026-04-30',
        reading_value          => 520.00,
        previous_reading_value => 500.00,
        consumption            => 20.00,
        period_month           => 4,
        period_year            => 2026,
    });

    return {
        tenant_a => $tenant_a,
        tenant_b => $tenant_b,
        calc     => $calc,
    };
}

plan tests => 5;

subtest 'fixed-percentage tenant unchanged' => sub {
    plan tests => 2;

    my $f = build_fixtures();
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    my $r = $calc->calculate_shares(year => 2026, month => 4);

    my ($a) = grep { $_->{tenant_id} == $f->{tenant_a}->id } @{ $r->{tenant_shares} };
    is($a->{utilities}{gas}{amount},   '45.00', 'Tenant A gas = 15% of 300');
    is($a->{utilities}{water}{amount}, '20.00', 'Tenant A water = 10% of 200');
};

subtest 'metered gas tenant' => sub {
    plan tests => 2;

    my $f = build_fixtures();
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    my $r = $calc->calculate_shares(year => 2026, month => 4);

    my ($b) = grep { $_->{tenant_id} == $f->{tenant_b}->id } @{ $r->{tenant_shares} };
    is($b->{utilities}{gas}{amount},     '60.00', 'Tenant B gas = 20/100 * 300 = 60');
    is($b->{utilities}{gas}{percentage}, '20.00', 'Tenant B gas effective % = 20');
};

subtest 'metered water with rain add-on' => sub {
    plan tests => 2;

    my $f = build_fixtures();
    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    my $r = $calc->calculate_shares(year => 2026, month => 4);

    my ($b) = grep { $_->{tenant_id} == $f->{tenant_b}->id } @{ $r->{tenant_shares} };
    # consumption share = 20/80 * 160 = 40
    # rain share        = 5% * 40 = 2
    # total             = 42
    is($b->{utilities}{water}{amount},     '42.00', 'Tenant B water = 40 + 2 = 42');
    is($b->{utilities}{water}{percentage}, '21.00', 'Tenant B water effective % = 21');
};

subtest 'missing metered inputs blocks finalization' => sub {
    plan tests => 1;

    my $f = build_fixtures();
    $schema->resultset('MeteredCalculationInput')->search(
        { utility_type => 'water' }
    )->delete;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    eval { $calc->calculate_shares(year => 2026, month => 4); };
    like($@, qr/metered/i, 'Missing metered inputs raises error mentioning metered');
};

subtest 'missing tenant reading blocks finalization' => sub {
    plan tests => 1;

    my $f = build_fixtures();
    $schema->resultset('GasReading')->search({ tenant_id => $f->{tenant_b}->id })->delete;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    eval { $calc->calculate_shares(year => 2026, month => 4); };
    like($@, qr/reading/i, 'Missing reading raises error mentioning reading');
};

# Cleanup
$schema->resultset('UtilityCalculationDetail')->delete_all;
$schema->resultset('MeteredCalculationInput')->delete_all;
$schema->resultset('UtilityCalculation')->delete_all;
$schema->resultset('GasReading')->delete_all;
$schema->resultset('WaterReading')->delete_all;
TestHelper::cleanup_test_data($schema);

done_testing();
