#!/usr/bin/env perl

# Renders the invoice template directly (no wkhtmltopdf) to check the
# "Detalii calcul contori" electricity box.

use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use File::Spec;
use Template;

binmode(Test::More->builder->$_, ':encoding(UTF-8)')
    for qw(output failure_output todo_output);

my $template_dir = File::Spec->catdir($FindBin::Bin, '..', '..', 'templates', 'pdf');

sub render {
    my (%item) = @_;

    my $tt = Template->new({
        INCLUDE_PATH => $template_dir,
        ENCODING     => 'utf8',
    }) or die Template->error();

    my $out = '';
    $tt->process('invoice.tt', {
        invoice   => { invoice_number => 'ARC 1', invoice_type => 'utility' },
        company   => { name => 'Test SRL' },
        tenant    => { name => 'Caferamica' },
        items     => [],
        formatted => { total => '1.397,25' },
        metered_breakdown => [ \%item ],
    }, \$out) or die $tt->error();

    return $out;
}

my %base = (
    utility_type       => 'electricity',
    previous_index     => '159.00',
    current_index      => '1034.00',
    tenant_units       => '875.00',
    general_units      => '2418.00',
    general_meter_name => 'General Meter - Building',
    ratio_pct          => '36.19',
    effective_pct      => '36.19',
    invoice_amount     => '3860.88',
    tenant_amount      => '1397.25',
    derivation_ok      => 1,
);

plan tests => 2;

subtest 'electricity box shows the meter derivation and the invoiced amount' => sub {
    plan tests => 8;

    my $html = render(%base);

    like($html, qr/Electricitate/,                      'box is labelled Electricitate');
    like($html, qr/Index anterior:\s*159\.00 kWh/,       'previous index with kWh');
    like($html, qr/Index curent:\s*1034\.00 kWh/,        'current index with kWh');
    like($html, qr/Consum:\s*875\.00 kWh/,               'tenant consumption');
    like($html, qr/2418\.00 kWh/,                        'general building consumption');
    like($html, qr/General Meter - Building/,            'names the general meter');
    like($html, qr{875\.00\s*/\s*2418\.00\s*=\s*36\.19%}, 'shows the ratio equation');
    like($html, qr/36\.19%\s*×\s*3860\.88 RON\s*=\s*<b>1397\.25 RON<\/b>/,
         'shows the billed percentage applied to the supplier invoice');
};

subtest 'electricity box drops the equation when the derivation does not reconcile' => sub {
    plan tests => 4;

    my $html = render(%base,
        tenant_units  => '0.00',
        general_units => '1274.00',
        ratio_pct     => '0.00',
        effective_pct => '0.63',
        invoice_amount => '2067.67',
        tenant_amount  => '13.03',
        derivation_ok  => 0,
    );

    like($html, qr/Cotă facturată:\s*0\.63%/, 'states the billed percentage plainly');
    unlike($html, qr{0\.00\s*/\s*1274\.00\s*=}, 'no contradictory ratio equation');
    like($html, qr/Index curent:\s*1034\.00 kWh/, 'readings are still shown');
    like($html, qr/0\.63%\s*×\s*2067\.67 RON\s*=\s*<b>13\.03 RON<\/b>/,
         'money line still reconciles with the invoice');
};
