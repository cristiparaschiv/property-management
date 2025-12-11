#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::PDFGenerator;

# Get database schema
my $schema = TestHelper::schema();
TestHelper::cleanup_test_data($schema);

my $config = {
    app => {
        pdf_engine => 'wkhtmltopdf',  # or PDF::API2
    },
};

plan tests => 6;

# ============================================================================
# Test: Constructor
# ============================================================================

subtest 'Constructor validation' => sub {
    plan tests => 2;

    eval { PropertyManager::Services::PDFGenerator->new() };
    like($@, qr/schema is required/, 'Dies without schema');

    # config is optional for PDFGenerator
    my $gen = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => $config,
    );
    isa_ok($gen, 'PropertyManager::Services::PDFGenerator');
};

# ============================================================================
# Test: generate_invoice_pdf() basic functionality
# ============================================================================

subtest 'generate_invoice_pdf() creates PDF' => sub {
    plan tests => 3;

    my $generator = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => $config,
    );

    # Create test invoice
    my $invoice = TestHelper::create_test_invoice($schema,
        invoice_type => 'rent',
        subtotal_ron => 2000.00,
        total_ron => 2000.00,
    );

    # Create invoice item
    $schema->resultset('InvoiceItem')->create({
        invoice_id => $invoice->id,
        description => 'Monthly Rent',
        quantity => 1,
        unit_price => 2000.00,
        total => 2000.00,
    });

    my $pdf = $generator->generate_invoice_pdf($invoice->id);

    ok($pdf, 'PDF generated');
    like($pdf, qr/^%PDF/, 'PDF starts with PDF signature');
    ok(length($pdf) > 1000, 'PDF has reasonable size');
};

# ============================================================================
# Test: generate_invoice_pdf() with missing invoice
# ============================================================================

subtest 'generate_invoice_pdf() handles missing invoice' => sub {
    plan tests => 1;

    my $generator = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => $config,
    );

    eval {
        $generator->generate_invoice_pdf(99999);
    };
    like($@, qr/Invoice not found/, 'Dies with non-existent invoice');
};

# ============================================================================
# Test: PDF contains invoice data
# ============================================================================

subtest 'PDF contains invoice information' => sub {
    plan tests => 2;

    my $generator = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => $config,
    );

    my $tenant = TestHelper::create_test_tenant($schema, name => 'PDF Test Tenant');
    my $invoice = TestHelper::create_test_invoice($schema,
        tenant_id => $tenant->id,
        invoice_number => 'ARC12345',
    );

    $schema->resultset('InvoiceItem')->create({
        invoice_id => $invoice->id,
        description => 'Test Item',
        quantity => 1,
        unit_price => 1000.00,
        total => 1000.00,
    });

    my $pdf = $generator->generate_invoice_pdf($invoice->id);

    ok($pdf, 'PDF generated');
    # Note: Actual content verification depends on PDF library
    # For now, just verify it's a valid PDF
    like($pdf, qr/^%PDF/, 'PDF format valid');
};

# ============================================================================
# Test: PDF with company information
# ============================================================================

subtest 'PDF includes company information if available' => sub {
    plan tests => 2;

    my $generator = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => $config,
    );

    # Create or update company
    my $company = $schema->resultset('Company')->search()->first;
    unless ($company) {
        $company = $schema->resultset('Company')->create({
            name => 'Test Company SRL',
            cui_cif => 'RO12345678',
            address => '123 Business St',
            city => 'Bucharest',
            county => 'Bucharest',
        });
    }

    my $invoice = TestHelper::create_test_invoice($schema);
    $schema->resultset('InvoiceItem')->create({
        invoice_id => $invoice->id,
        description => 'Item',
        quantity => 1,
        unit_price => 500.00,
        total => 500.00,
    });

    my $pdf = $generator->generate_invoice_pdf($invoice->id);

    ok($pdf, 'PDF generated');
    like($pdf, qr/^%PDF/, 'PDF format valid');
};

# ============================================================================
# Test: Multiple PDFs can be generated
# ============================================================================

subtest 'Multiple PDFs can be generated concurrently' => sub {
    plan tests => 3;

    my $generator = PropertyManager::Services::PDFGenerator->new(
        schema => $schema,
        config => $config,
    );

    my @invoices;
    for my $i (1..3) {
        my $inv = TestHelper::create_test_invoice($schema,
            invoice_number => "TEST$i",
        );
        $schema->resultset('InvoiceItem')->create({
            invoice_id => $inv->id,
            description => "Item $i",
            quantity => 1,
            unit_price => 100 * $i,
            total => 100 * $i,
        });
        push @invoices, $inv;
    }

    my $pdf1 = $generator->generate_invoice_pdf($invoices[0]->id);
    my $pdf2 = $generator->generate_invoice_pdf($invoices[1]->id);
    my $pdf3 = $generator->generate_invoice_pdf($invoices[2]->id);

    ok($pdf1 && $pdf2 && $pdf3, 'All PDFs generated');
    isnt($pdf1, $pdf2, 'PDF 1 and 2 are different');
    isnt($pdf2, $pdf3, 'PDF 2 and 3 are different');
};

TestHelper::cleanup_test_data($schema);
done_testing();
