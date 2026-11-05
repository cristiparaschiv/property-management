#!/usr/bin/env perl

# Ștorno / credit-note received invoices. A supplier that refunds a charge
# sends a negative invoice; it is recorded as its own line and settled through
# the normal "mark as paid" flow, which returns the money to the company
# balance. Only "other" invoices may go negative - the tenant-billed utility
# types still reject it, because a negative has no defined meaning yet in the
# percentage splits that reach tenant invoices.

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

TestHelper::cleanup_test_data($schema);
TestHelper::create_test_company($schema);

sub provider_for {
    my ($type) = @_;
    return TestHelper::create_test_provider(
        $schema, type => $type, name => "Provider $type"
    );
}

sub payload {
    my (%over) = @_;
    return {
        provider_id    => $over{provider_id},
        invoice_number => $over{invoice_number} || 'STORNO-1',
        invoice_date   => '2026-10-05',
        due_date       => '2026-10-20',
        amount         => $over{amount},
        utility_type   => $over{utility_type},
        period_start   => '2026-09-01',
        period_end     => '2026-09-30',
    };
}

plan tests => 5;

subtest 'a negative "other" invoice can be recorded' => sub {
    plan tests => 3;

    my $p = provider_for('other');
    my $r = TestHelper::auth_post($test, '/api/received-invoices',
        payload(provider_id => $p->id, utility_type => 'other', amount => -12100));

    is($r->code, 200, 'create accepted');
    my $inv = decode_json($r->content)->{data}{invoice};
    is(sprintf('%.2f', $inv->{amount}), '-12100.00', 'stored as a negative amount');
    is($inv->{utility_type}, 'other', 'recorded against the other utility type');
};

subtest 'a negative invoice is refused for a tenant-billed utility type' => sub {
    plan tests => 2;

    my $p = provider_for('gas');
    my $r = TestHelper::auth_post($test, '/api/received-invoices',
        payload(provider_id => $p->id, utility_type => 'gas',
                amount => -12100, invoice_number => 'STORNO-GAS'));

    is($r->code, 400, 'create rejected');
    ok(!$schema->resultset('ReceivedInvoice')->search({ invoice_number => 'STORNO-GAS' })->count,
       'nothing was stored');
};

subtest 'an existing negative invoice cannot be moved to a tenant-billed type' => sub {
    plan tests => 2;

    my $p = provider_for('other');
    my $c = TestHelper::auth_post($test, '/api/received-invoices',
        payload(provider_id => $p->id, utility_type => 'other',
                amount => -500, invoice_number => 'STORNO-MOVE'));
    my $id = decode_json($c->content)->{data}{invoice}{id};

    # The amount is not in this payload, so the guard has to look at the row.
    my $r = TestHelper::auth_put($test, "/api/received-invoices/$id",
        { utility_type => 'gas' });

    is($r->code, 400, 'update rejected');
    is($schema->resultset('ReceivedInvoice')->find($id)->utility_type, 'other',
       'the invoice kept its type');
};

subtest 'the amount of a negative "other" invoice can still be edited' => sub {
    plan tests => 2;

    my $p = provider_for('other');
    my $c = TestHelper::auth_post($test, '/api/received-invoices',
        payload(provider_id => $p->id, utility_type => 'other',
                amount => -500, invoice_number => 'STORNO-EDIT'));
    my $id = decode_json($c->content)->{data}{invoice}{id};

    my $r = TestHelper::auth_put($test, "/api/received-invoices/$id", { amount => -750 });

    is($r->code, 200, 'update accepted');
    is(sprintf('%.2f', $schema->resultset('ReceivedInvoice')->find($id)->amount),
       '-750.00', 'new amount stored');
};

subtest 'settling a negative invoice returns the money to the company balance' => sub {
    plan tests => 3;

    # The mark-paid route updates the company row with id 1 specifically, so
    # that is the row this test has to watch. Other tests in the suite may
    # leave the first company at a different id, so pin it down here.
    my $company = $schema->resultset('Company')->find(1)
        || $schema->resultset('Company')->create({
            id => 1, name => 'Storno Test SRL', cui_cif => 'RO12345678',
            j_number => 'J40/1234/2025', address => '123 Test Street',
            city => 'Bucharest', county => 'Bucharest', postal_code => '012345',
            bank_name => 'Test Bank', iban => 'RO49AAAA1B31007593840000',
            phone => '0212345678', email => 'company@test.com',
        });
    $company->update({ balance => 0 });

    my $p = provider_for('other');
    my $c = TestHelper::auth_post($test, '/api/received-invoices',
        payload(provider_id => $p->id, utility_type => 'other',
                amount => -12100, invoice_number => 'STORNO-PAY'));
    my $id = decode_json($c->content)->{data}{invoice}{id};

    my $r = TestHelper::auth_post($test, "/api/received-invoices/$id/mark-paid",
        { paid_date => '2026-10-06' });

    is($r->code, 200, 'settle accepted');
    ok($schema->resultset('ReceivedInvoice')->find($id)->is_paid, 'marked as settled');

    $company->discard_changes;
    is(sprintf('%.2f', $company->balance), '12100.00',
       'the refund increased the company balance');
};
