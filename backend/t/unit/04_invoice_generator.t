#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::InvoiceGenerator;
use PropertyManager::Services::BNRExchangeRate;

# Get database schema
my $schema = TestHelper::schema();
TestHelper::cleanup_test_data($schema);

# Setup services
my $config = {
    app => {
        invoice_prefix => 'ARC',
        invoice_number_padding => 5,
    },
    jwt => { secret_key => 'test' },
};

my $bnr_service = PropertyManager::Services::BNRExchangeRate->new(
    schema => $schema,
    config => $config,
);

# Cache test exchange rate
$bnr_service->cache_rate('2025-12-09', 4.9750, 'BNR');

my $generator = PropertyManager::Services::InvoiceGenerator->new(
    schema => $schema,
    config => $config,
    exchange_rate_service => $bnr_service,
);

plan tests => 7;

# ============================================================================
# Test: Constructor
# ============================================================================

subtest 'Constructor validation' => sub {
    plan tests => 4;

    eval { PropertyManager::Services::InvoiceGenerator->new() };
    like($@, qr/schema is required/, 'Dies without schema');

    eval { PropertyManager::Services::InvoiceGenerator->new(schema => $schema) };
    like($@, qr/config is required/, 'Dies without config');

    eval { PropertyManager::Services::InvoiceGenerator->new(schema => $schema, config => $config) };
    like($@, qr/exchange_rate_service is required/, 'Dies without exchange_rate_service');

    my $gen = PropertyManager::Services::InvoiceGenerator->new(
        schema => $schema,
        config => $config,
        exchange_rate_service => $bnr_service,
    );
    isa_ok($gen, 'PropertyManager::Services::InvoiceGenerator');
};

# ============================================================================
# Test: get_next_invoice_number()
# ============================================================================

subtest 'get_next_invoice_number() generates sequential numbers' => sub {
    plan tests => 6;

    # Clean invoices
    $schema->resultset('InvoiceItem')->delete_all;
    $schema->resultset('Invoice')->delete_all;

    my $num1 = $generator->get_next_invoice_number();
    is($num1, 'ARC00001', 'First invoice number');

    # Create an invoice with this number
    my $tenant = TestHelper::create_test_tenant($schema);
    $schema->resultset('Invoice')->create({
        invoice_number => $num1,
        invoice_type => 'rent',
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
        due_date => '2025-12-31',
        subtotal_ron => 1000,
        total_ron => 1000,
    });

    my $num2 = $generator->get_next_invoice_number();
    is($num2, 'ARC00002', 'Second invoice number');

    # Create an invoice with num2
    $schema->resultset('Invoice')->create({
        invoice_number => $num2,
        invoice_type => 'rent',
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
        due_date => '2025-12-31',
        subtotal_ron => 1000,
        total_ron => 1000,
    });

    my $num3 = $generator->get_next_invoice_number();
    is($num3, 'ARC00003', 'Third invoice number');

    # Verify format
    like($num1, qr/^ARC\d{5}$/, 'Number matches format');
    like($num2, qr/^ARC\d{5}$/, 'Number matches format');
    like($num3, qr/^ARC\d{5}$/, 'Number matches format');
};

# ============================================================================
# Test: create_rent_invoice()
# ============================================================================

subtest 'create_rent_invoice() creates complete invoice' => sub {
    plan tests => 11;

    my $tenant = TestHelper::create_test_tenant($schema,
        name => 'Rent Tenant',
        rent_amount_eur => 500.00,
    );

    my $invoice = $generator->create_rent_invoice(
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
        due_date => '2025-12-31',
        notes => 'Test rent invoice',
    );

    ok($invoice, 'Invoice created');
    like($invoice->invoice_number, qr/^ARC\d{5}$/, 'Invoice number generated');
    is($invoice->invoice_type, 'rent', 'Type is rent');
    is($invoice->tenant_id, $tenant->id, 'Tenant ID matches');
    is($invoice->invoice_date, '2025-12-09', 'Invoice date matches');
    is($invoice->due_date, '2025-12-31', 'Due date matches');
    ok(abs($invoice->exchange_rate - 4.9750) < 0.0001, 'Exchange rate applied');
    ok(abs($invoice->subtotal_eur - 500.00) < 0.01, 'Subtotal EUR matches rent');
    ok(abs($invoice->subtotal_ron - 2487.50) < 0.01, 'Subtotal RON calculated (500 * 4.9750)');
    ok(abs($invoice->total_ron - 2487.50) < 0.01, 'Total RON matches');

    # Check invoice item
    my @items = $invoice->items->all;
    is(scalar @items, 1, 'One invoice item created for rent');
};

# ============================================================================
# Test: create_rent_invoice() with additional items
# ============================================================================

subtest 'create_rent_invoice() with additional items' => sub {
    plan tests => 5;

    my $tenant = TestHelper::create_test_tenant($schema,
        name => 'Rent+ Tenant',
        rent_amount_eur => 400.00,
    );

    my $invoice = $generator->create_rent_invoice(
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
        due_date => '2025-12-31',
        additional_items => [
            {
                description => 'Parking',
                quantity => 1,
                unit_price => 100.00,
                vat_rate => 0,
            },
            {
                description => 'Storage',
                quantity => 1,
                unit_price => 50.00,
                vat_rate => 0,
            },
        ],
    );

    ok($invoice, 'Invoice created');

    my @items = $invoice->items->all;
    is(scalar @items, 3, 'Three items: rent + 2 additional');

    # Total should be rent + parking + storage
    # (400 * 4.9750) + 100 + 50 = 1990 + 150 = 2140
    ok(abs($invoice->subtotal_ron - 2140.00) < 0.01, 'Subtotal includes additional items');
    ok(abs($invoice->total_ron - 2140.00) < 0.01, 'Total includes additional items');

    my ($parking) = grep { $_->description eq 'Parking' } @items;
    ok(abs($parking->total - 100.00) < 0.01, 'Parking item amount correct');
};

# ============================================================================
# Test: create_rent_invoice() default due date
# ============================================================================

subtest 'create_rent_invoice() calculates default due date' => sub {
    plan tests => 2;

    my $tenant = TestHelper::create_test_tenant($schema, name => 'Due Date Tenant');

    my $invoice = $generator->create_rent_invoice(
        tenant_id => $tenant->id,
        invoice_date => '2025-12-01',
        # No due_date specified
    );

    ok($invoice, 'Invoice created');
    is($invoice->due_date, '2025-12-16', 'Due date is 15 days from invoice date');
};

# ============================================================================
# Test: create_rent_invoice() validation
# ============================================================================

subtest 'create_rent_invoice() validates parameters' => sub {
    plan tests => 2;

    eval {
        $generator->create_rent_invoice();
    };
    like($@, qr/tenant_id is required/, 'Dies without tenant_id');

    eval {
        $generator->create_rent_invoice(tenant_id => 99999);
    };
    like($@, qr/Tenant not found/, 'Dies with invalid tenant_id');
};

# ============================================================================
# Test: Invoice number is unique
# ============================================================================

subtest 'Invoice numbers are unique and sequential' => sub {
    plan tests => 3;

    my $tenant = TestHelper::create_test_tenant($schema, name => 'Sequential Tenant');

    my $inv1 = $generator->create_rent_invoice(
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
    );

    my $inv2 = $generator->create_rent_invoice(
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
    );

    my $inv3 = $generator->create_rent_invoice(
        tenant_id => $tenant->id,
        invoice_date => '2025-12-09',
    );

    isnt($inv1->invoice_number, $inv2->invoice_number, 'Invoice 1 and 2 have different numbers');
    isnt($inv2->invoice_number, $inv3->invoice_number, 'Invoice 2 and 3 have different numbers');
    isnt($inv1->invoice_number, $inv3->invoice_number, 'Invoice 1 and 3 have different numbers');
};

TestHelper::cleanup_test_data($schema);
done_testing();
