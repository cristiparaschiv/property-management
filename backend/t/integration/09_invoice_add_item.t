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

# A tenant + a simple invoice with one system-generated base line.
my $tenant = TestHelper::create_test_tenant($schema, name => 'Add/Del Item Tenant');
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
my $base_item = $invoice->create_related('items', {
    description => 'Contravaloare utilități - Iulie 2026',
    quantity    => 1,
    unit_price  => 210.04,
    vat_rate    => 0,
    total       => 210.04,
    sort_order  => 1,
    is_manual   => 0,
});

my $manual_item_id;

subtest 'POST items adds a NEGATIVE manual correction and recomputes total' => sub {
    plan tests => 5;

    my $res = TestHelper::auth_post($test, '/api/invoices/' . $invoice->id . '/items', {
        description => 'Corecție calcul Iunie 2026',
        quantity    => 1,
        unit_price  => -45.20,
        vat_rate    => 0,
    });
    is($res->code, 200, 'add item OK');

    my $data = decode_json($res->content);
    is(sprintf('%.2f', $data->{data}{item}{total}), '-45.20', 'negative line total stored');
    is($data->{data}{item}{is_manual}, 1, 'added line is flagged manual');
    $manual_item_id = $data->{data}{item}{id};

    $invoice->discard_changes;
    is(sprintf('%.2f', $invoice->total_ron), '164.84', 'total recomputed (210.04 - 45.20)');
    is($base_item->discard_changes->is_manual, 0, 'base line stays system (is_manual=0)');
};

subtest 'DELETE cannot remove a system base line' => sub {
    plan tests => 2;
    my $res = TestHelper::auth_delete($test,
        '/api/invoices/' . $invoice->id . '/items/' . $base_item->id);
    is($res->code, 403, 'deleting base line is forbidden');
    $invoice->discard_changes;
    is(sprintf('%.2f', $invoice->total_ron), '164.84', 'total unchanged after rejected delete');
};

subtest 'DELETE removes a manual line and recomputes total' => sub {
    plan tests => 2;
    my $res = TestHelper::auth_delete($test,
        '/api/invoices/' . $invoice->id . '/items/' . $manual_item_id);
    is($res->code, 200, 'delete manual line OK');
    $invoice->discard_changes;
    is(sprintf('%.2f', $invoice->total_ron), '210.04', 'total restored (210.04)');
};

# Cleanup
$invoice->items->delete;
$invoice->delete;

done_testing;
