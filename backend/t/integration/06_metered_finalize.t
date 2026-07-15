#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";
use TestHelper;
use JSON::XS;

my $test   = TestHelper::app();
my $schema = TestHelper::schema();

# Clean slate for the involved tables
for my $rs (qw(UtilityCalculationDetail MeteredCalculationInput UtilityCalculation
               GasReading WaterReading ReceivedInvoice TenantUtilityPercentage)) {
    eval { $schema->resultset($rs)->delete_all };
}

my $tenant = TestHelper::create_test_tenant($schema, name => 'Finalize Metered');
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'gas', percentage => 0, uses_meter => 1 });
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'water', percentage => 20, uses_meter => 1 });

my $gas_inv = TestHelper::create_test_received_invoice($schema,
    utility_type => 'gas', period_start => '2026-06-01', period_end => '2026-06-30',
    invoice_date => '2026-06-30', due_date => '2026-07-15', amount => 300.00);
my $water_inv = TestHelper::create_test_received_invoice($schema,
    utility_type => 'water', period_start => '2026-06-01', period_end => '2026-06-30',
    invoice_date => '2026-06-30', due_date => '2026-07-15', amount => 1883.58);

$schema->resultset('GasReading')->create({ tenant_id => $tenant->id,
    reading_date => '2026-06-30', reading_value => 104.30, previous_reading_value => 100.00,
    consumption => 4.30, period_month => 6, period_year => 2026 });
$schema->resultset('WaterReading')->create({ tenant_id => $tenant->id,
    reading_date => '2026-06-30', reading_value => 101.10, previous_reading_value => 100.00,
    consumption => 1.10, period_month => 6, period_year => 2026 });

my $calc = $schema->resultset('UtilityCalculation')->create({
    period_month => 6, period_year => 2026, is_finalized => 0 });
$schema->resultset('MeteredCalculationInput')->create({ calculation_id => $calc->id,
    received_invoice_id => $gas_inv->id, utility_type => 'gas', total_units => 57.00 });
$schema->resultset('MeteredCalculationInput')->create({ calculation_id => $calc->id,
    received_invoice_id => $water_inv->id, utility_type => 'water', total_units => 47.00,
    consumption_amount => 1104.44, rain_amount => 779.14 });

# Simulate the bug's aftermath: persisted details are WRONG (flat) before finalize.
$schema->resultset('UtilityCalculationDetail')->create({ calculation_id => $calc->id,
    tenant_id => $tenant->id, utility_type => 'gas', received_invoice_id => $gas_inv->id,
    percentage => 0.00, amount => 0.00 });
$schema->resultset('UtilityCalculationDetail')->create({ calculation_id => $calc->id,
    tenant_id => $tenant->id, utility_type => 'water', received_invoice_id => $water_inv->id,
    percentage => 20.00, amount => 376.72 });

subtest 'finalize recomputes metered details to the meter-based amounts' => sub {
    plan tests => 5;

    my $res = TestHelper::auth_post($test, '/api/utility-calculations/' . $calc->id . '/finalize', {});
    is($res->code, 200, 'finalize OK');

    my $gas_d = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'gas' })->first;
    my $water_d = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'water' })->first;

    is(sprintf('%.2f', $gas_d->amount),   '22.63',  'gas amount is meter-based (4.3/57 * 300)');
    is(sprintf('%.2f', $gas_d->percentage), '7.54', 'gas percentage is meter-based');
    is(sprintf('%.2f', $water_d->amount), '181.68', 'water amount is meter-based (rain + consum)');
    is(sprintf('%.2f', $water_d->percentage), '9.65', 'water effective percentage');
};

done_testing;
