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

# Fixtures: o factura de apa si un calcul
my $water_invoice = TestHelper::create_test_received_invoice(
    $schema,
    utility_type => 'water',
    period_start => '2026-06-01',
    period_end   => '2026-06-30',
    invoice_date => '2026-06-30',
    due_date     => '2026-07-15',
    amount       => 1883.58,
);
my $calc = $schema->resultset('UtilityCalculation')->create({
    period_year => 2026, period_month => 6, is_finalized => 0,
});

subtest 'POST metered-inputs water: consumption_amount derivat = factura - pluviala' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_post($test, '/api/metered-inputs', {
        calculation_id      => $calc->id,
        received_invoice_id => $water_invoice->id,
        utility_type        => 'water',
        total_units         => 47,
        rain_amount         => 779.14,
        # NB: fara consumption_amount
    });
    is($res->code, 200, 'Salvare OK fara consumption_amount');

    my $data = decode_json($res->content);
    my $saved = $data->{data}{input};
    is(sprintf('%.2f', $saved->{rain_amount}), '779.14', 'rain_amount pastrat');
    is(sprintf('%.2f', $saved->{consumption_amount}), '1104.44',
        'consumption_amount derivat = 1883.58 - 779.14');
};

# Curatenie
$schema->resultset('MeteredCalculationInput')->delete_all;
$schema->resultset('UtilityCalculation')->delete_all;
$schema->resultset('ReceivedInvoice')->delete_all;

done_testing;
