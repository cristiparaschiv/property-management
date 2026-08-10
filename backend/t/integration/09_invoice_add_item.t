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

# A tenant + a simple invoice with one base line item.
my $tenant = TestHelper::create_test_tenant($schema, name => 'Add Item Tenant');
my $invoice = $schema->resultset('Invoice')->create({
    invoice_number => 'TEST-ADDITEM-1',
    invoice_type   => 'utility',
    tenant_id      => $tenant->id,
    invoice_date   => '2026-08-03',
    due_date       => '2026-08-18',
    subtotal_ron   => 210.04,
    vat_amount     => 0,
    total_ron      => 210.04,
});
$invoice->create_related('items', {
    description => 'Contravaloare utilități - Iulie 2026',
    quantity    => 1,
    unit_price  => 210.04,
    vat_rate    => 0,
    total       => 210.04,
    sort_order  => 1,
});

subtest 'POST /api/invoices/:id/items adds a NEGATIVE correction and recomputes total' => sub {
    plan tests => 4;

    my $res = TestHelper::auth_post($test, '/api/invoices/' . $invoice->id . '/items', {
        description => 'Corecție calcul Iunie 2026',
        quantity    => 1,
        unit_price  => -45.20,
        vat_rate    => 0,
    });
    is($res->code, 200, 'add item OK');

    my $data = decode_json($res->content);
    is(sprintf('%.2f', $data->{data}{item}{total}), '-45.20', 'negative line total stored');

    $invoice->discard_changes;
    is(sprintf('%.2f', $invoice->subtotal_ron), '164.84', 'subtotal recomputed (210.04 - 45.20)');
    is(sprintf('%.2f', $invoice->total_ron),    '164.84', 'total recomputed');
};

# Cleanup
$invoice->items->delete;
$invoice->delete;

done_testing;
