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

# Clean the involved tables
for my $rs (qw(InvoiceItem Invoice UtilityCalculationDetail UtilityCalculation
               GasReading WaterReading MeterReading ElectricityMeter
               TenantUtilityPercentage Tenant)) {
    eval { $schema->resultset($rs)->delete_all };
}

my $tenant = TestHelper::create_test_tenant($schema, name => 'Overview Co', phone => undef);
# Standing rate for electricity (used by data completeness + allocation "0 bar")
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'electricity', percentage => 30, uses_meter => 0 });
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'gas', percentage => 0, uses_meter => 1 });

# Two invoices: one paid (22 days to pay), one unpaid & overdue.
$schema->resultset('Invoice')->create({
    invoice_number => 'OV-1', invoice_type => 'utility', tenant_id => $tenant->id,
    invoice_date => '2026-01-01', due_date => '2026-01-15',
    subtotal_ron => 100, vat_amount => 0, total_ron => 100,
    is_paid => 1, paid_date => '2026-01-23' });
$schema->resultset('Invoice')->create({
    invoice_number => 'OV-2', invoice_type => 'utility', tenant_id => $tenant->id,
    invoice_date => '2026-02-01', due_date => '2026-02-15',
    subtotal_ron => 300, vat_amount => 0, total_ron => 300,
    is_paid => 0, paid_date => undef });

# A finalized calc with electricity + gas details for this tenant.
my $calc = $schema->resultset('UtilityCalculation')->create({
    period_month => 6, period_year => 2026, is_finalized => 1 });
$schema->resultset('UtilityCalculationDetail')->create({
    calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'electricity',
    percentage => 30, amount => 150 });
$schema->resultset('UtilityCalculationDetail')->create({
    calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'gas',
    percentage => 7.5, amount => 22.63 });

# Gas readings: June present, May MISSING (must appear as null, not 0).
$schema->resultset('GasReading')->create({ tenant_id => $tenant->id,
    reading_date => '2026-06-30', reading_value => 104.3, previous_reading_value => 100,
    consumption => 4.3, period_month => 6, period_year => 2026 });

subtest 'tenant overview aggregates KPIs, allocation, consumption, completeness' => sub {
    plan tests => 10;

    my $res = TestHelper::auth_get($test, '/api/tenants/' . $tenant->id . '/overview');
    is($res->code, 200, 'overview OK');
    my $d = decode_json($res->content)->{data};

    is($d->{tenant}{id}, $tenant->id, 'tenant returned');

    is(sprintf('%.2f', $d->{kpis}{billed_ron}),      '400.00', 'billed = 100 + 300');
    is(sprintf('%.2f', $d->{kpis}{paid_ron}),        '100.00', 'paid = 100');
    is(sprintf('%.2f', $d->{kpis}{outstanding_ron}), '300.00', 'outstanding = 300');
    is($d->{kpis}{open_count}, 1, 'one open invoice');
    is($d->{kpis}{avg_days_to_pay}, 22, 'avg days to pay = 22');

    my %alloc = map { $_->{utility_type} => $_->{total_ron} } @{ $d->{utility_allocation} };
    is(sprintf('%.2f', $alloc{electricity}), '150.00', 'electricity allocation summed');

    # Gas series: June has a value; some earlier period is null (gap), never 0.
    my $gas = $d->{metered_consumption}{gas} || [];
    my ($june) = grep { $_->{period} eq '2026-06' } @$gas;
    is($june && $june->{value} + 0, 4.3, 'gas June consumption present');

    ok((grep { $_ eq 'phone' } @{ $d->{data_completeness}{empty_fields} }),
        'phone flagged as empty');
};

done_testing;
