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

# A tenant that uses a meter for gas and water.
my $tenant = TestHelper::create_test_tenant($schema, name => 'Create Metered');
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'gas', percentage => 0, uses_meter => 1 });
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'water', percentage => 20, uses_meter => 1 });

my $gas_inv = TestHelper::create_test_received_invoice($schema,
    utility_type => 'gas', period_start => '2026-06-01', period_end => '2026-06-30',
    invoice_date => '2026-06-30', due_date => '2026-07-15', amount => 300.00);

# Regression: creating a calculation for a period that has a metered tenant but
# NO existing calculation row must NOT die with "calculation_id required for
# metered billing". The calculation row has to exist before shares are resolved.
subtest 'create calculation with a metered tenant and no existing calc succeeds' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_year => 2026, period_month => 6, overrides => {},
    });
    is($res->code, 200, 'create OK (no calculation_id die)');
    my $data = decode_json($res->content);
    ok($data->{success}, 'success flag true');
    ok($data->{data}{calculation}{id}, 'calculation id returned');
};

# Re-saving the draft (e.g. clicking "Salvează Calcul" after entering meter
# inputs) must NOT wipe the metered_calculation_inputs rows.
subtest 'metered inputs survive re-saving the draft calculation' => sub {
    plan tests => 3;

    my $r1 = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_year => 2026, period_month => 6, overrides => {},
    });
    my $cid = decode_json($r1->content)->{data}{calculation}{id};

    my $save = TestHelper::auth_post($test, '/api/metered-inputs', {
        calculation_id => $cid, received_invoice_id => $gas_inv->id,
        utility_type => 'gas', total_units => 57,
    });
    is($save->code, 200, 'metered input saved');

    my $r2 = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_year => 2026, period_month => 6, overrides => {},
    });
    is($r2->code, 200, 're-save calculation OK');

    my $count = $schema->resultset('MeteredCalculationInput')->search({
        utility_type => 'gas' })->count;
    is($count, 1, 'gas metered input survived re-save');
};

done_testing;
