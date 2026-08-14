#!/usr/bin/env perl
# Reproduces the production bug: a draft calc froze a non-metered (electricity)
# percentage when it was created; the operator later updated the standing
# percentage via "Salvează %" (tenant_utility_percentages). Finalize must bill
# the CURRENT standing percentage, not the frozen draft detail.
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

for my $rs (qw(UtilityCalculationDetail MeteredCalculationInput UtilityCalculation
               ReceivedInvoice TenantUtilityPercentage Tenant)) {
    eval { $schema->resultset($rs)->delete_all };
}

my $tenant = TestHelper::create_test_tenant($schema, name => 'DB Pct Tenant');
# Standing percentage as updated via "Salvează %" AFTER the draft was created.
$schema->resultset('TenantUtilityPercentage')->create({
    tenant_id => $tenant->id, utility_type => 'electricity', percentage => 40, uses_meter => 0 });

my $inv = TestHelper::create_test_received_invoice($schema,
    utility_type => 'electricity', period_start => '2026-07-01', period_end => '2026-07-31',
    invoice_date => '2026-07-31', due_date => '2026-08-15', amount => 1000.00);

# A draft calc whose persisted electricity detail is STALE (30%, the value that
# was in the DB when the draft was created) — this is what the UI froze.
my $calc = $schema->resultset('UtilityCalculation')->create({
    period_month => 7, period_year => 2026, is_finalized => 0 });
$schema->resultset('UtilityCalculationDetail')->create({
    calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'electricity',
    percentage => 30, amount => 300 });

subtest 'finalize bills the current DB standing %, not the frozen draft detail' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_post($test, '/api/utility-calculations/' . $calc->id . '/finalize', {});
    is($res->code, 200, 'finalize OK');

    my $d = $schema->resultset('UtilityCalculationDetail')->search({
        calculation_id => $calc->id, tenant_id => $tenant->id, utility_type => 'electricity' })->first;
    is(sprintf('%.2f', $d->percentage), '40.00', 'electricity % = current DB standing (40), not frozen 30');
    is(sprintf('%.2f', $d->amount),     '400.00', 'electricity amount = 40% of 1000');
};

# Cleanup
$schema->resultset('UtilityCalculationDetail')->delete_all;
$schema->resultset('UtilityCalculation')->delete_all;
$schema->resultset('ReceivedInvoice')->delete_all;

done_testing;
