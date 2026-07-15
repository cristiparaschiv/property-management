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

sub wipe {
    for my $rs (qw(UtilityCalculationDetail MeteredCalculationInput UtilityCalculation
                   GasReading WaterReading ReceivedInvoice TenantUtilityPercentage)) {
        eval { $schema->resultset($rs)->delete_all };
    }
}

# Tenant: fixed-% electricity (30) in DB, metered gas + water.
sub build {
    wipe();
    my $tenant = TestHelper::create_test_tenant($schema, name => 'Elec Plus Metered');
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id => $tenant->id, utility_type => 'electricity', percentage => 30, uses_meter => 0 });
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id => $tenant->id, utility_type => 'gas', percentage => 0, uses_meter => 1 });
    $schema->resultset('TenantUtilityPercentage')->create({
        tenant_id => $tenant->id, utility_type => 'water', percentage => 20, uses_meter => 1 });

    my $elec_inv = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity', period_start => '2026-06-01', period_end => '2026-06-30',
        invoice_date => '2026-06-30', due_date => '2026-07-15', amount => 500.00);
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

    return ($tenant, $gas_inv, $water_inv);
}

sub elec_detail {
    my ($cid, $tid) = @_;
    return $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $cid, tenant_id => $tid, utility_type => 'electricity' })->first;
}

sub save_meters {
    my ($cid, $gas_inv, $water_inv) = @_;
    TestHelper::auth_post($test, '/api/metered-inputs', {
        calculation_id => $cid, received_invoice_id => $gas_inv->id, utility_type => 'gas', total_units => 57 });
    TestHelper::auth_post($test, '/api/metered-inputs', {
        calculation_id => $cid, received_invoice_id => $water_inv->id, utility_type => 'water',
        total_units => 47, rain_amount => 779.14 });
}

# The real-world failure: a draft created (e.g. by ensureCalculation while
# saving a meter input) before the electricity % was in the frontend state
# sends `electricity => 0`, which shadows the DB 30% -> no electricity detail.
# Finalize must recover it from the DB percentage.
subtest 'finalize recovers a non-metered detail dropped by a stale draft override' => sub {
    plan tests => 5;

    my ($tenant, $gas_inv, $water_inv) = build();

    my $c = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_year => 2026, period_month => 6,
        overrides => { $tenant->id => { electricity => 0 } },   # stale/zero override
    });
    is($c->code, 200, 'create OK');
    my $cid = decode_json($c->content)->{data}{calculation}{id};

    ok(!elec_detail($cid, $tenant->id), 'electricity missing after stale-override draft (documents the bug)');

    save_meters($cid, $gas_inv, $water_inv);

    my $f = TestHelper::auth_post($test, '/api/utility-calculations/' . $cid . '/finalize', {});
    is($f->code, 200, 'finalize OK');

    my $ed = elec_detail($cid, $tenant->id);
    ok($ed, 'electricity detail recovered after finalize');
    is(sprintf('%.2f', $ed ? $ed->amount : 0), '150.00', 'electricity = 30% of 500 (from DB percentage)') if $ed;
};

# An ad-hoc per-calc percentage that WAS persisted at create time must survive
# finalize (not be reverted to the DB percentage).
subtest 'finalize preserves a persisted ad-hoc non-metered override' => sub {
    plan tests => 3;

    my ($tenant, $gas_inv, $water_inv) = build();

    my $c = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_year => 2026, period_month => 6,
        overrides => { $tenant->id => { electricity => 50 } },  # ad-hoc, differs from DB 30
    });
    my $cid = decode_json($c->content)->{data}{calculation}{id};
    save_meters($cid, $gas_inv, $water_inv);

    my $f = TestHelper::auth_post($test, '/api/utility-calculations/' . $cid . '/finalize', {});
    is($f->code, 200, 'finalize OK');

    my $ed = elec_detail($cid, $tenant->id);
    ok($ed, 'electricity detail present');
    is(sprintf('%.2f', $ed ? $ed->amount : 0), '250.00', 'ad-hoc 50% preserved (250 = 50% of 500)') if $ed;
};

# Metered amounts remain correct through the full recompute.
subtest 'finalize still computes metered gas/water correctly' => sub {
    plan tests => 3;

    my ($tenant, $gas_inv, $water_inv) = build();
    my $c = TestHelper::auth_post($test, '/api/utility-calculations', {
        period_year => 2026, period_month => 6, overrides => { $tenant->id => { electricity => 30 } } });
    my $cid = decode_json($c->content)->{data}{calculation}{id};
    save_meters($cid, $gas_inv, $water_inv);
    TestHelper::auth_post($test, '/api/utility-calculations/' . $cid . '/finalize', {});

    my $gas = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $cid, tenant_id => $tenant->id, utility_type => 'gas' })->first;
    my $water = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $cid, tenant_id => $tenant->id, utility_type => 'water' })->first;
    ok($gas && $water, 'gas and water details present');
    is(sprintf('%.2f', $gas->amount),   '22.63',  'gas = 4.3/57 * 300');
    is(sprintf('%.2f', $water->amount), '181.68', 'water = rain + consumption share');
};

done_testing;
