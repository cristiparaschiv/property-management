package PropertyManager::Routes::Invoices;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use PropertyManager::Services::InvoiceGenerator;
use PropertyManager::Services::BNRExchangeRate;
use PropertyManager::Services::PDFGenerator;
use Try::Tiny;

prefix '/api/invoices';

my ($invoice_gen, $pdf_gen, $bnr_service);

hook 'before' => sub {
    $bnr_service ||= PropertyManager::Services::BNRExchangeRate->new(schema => schema, config => config);
    $invoice_gen ||= PropertyManager::Services::InvoiceGenerator->new(
        schema => schema,
        config => config,
        exchange_rate_service => $bnr_service,
    );
    $pdf_gen ||= PropertyManager::Services::PDFGenerator->new(schema => schema);
};

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{tenant_id} = query_parameters->get('tenant_id') if query_parameters->get('tenant_id');
    $search->{invoice_type} = query_parameters->get('type') if query_parameters->get('type');
    $search->{is_paid} = query_parameters->get('paid') ? 1 : 0 if defined query_parameters->get('paid');

    my @invoices = schema->resultset('Invoice')->search($search, {
        order_by => { -desc => 'invoice_date' },
        prefetch => 'tenant',
    })->all;

    my @data = map {
        my %inv = $_->get_columns;
        # Use tenant name or client_name for generic invoices
        $inv{tenant_name} = $_->tenant ? $_->tenant->name : $_->client_name;
        # Add total_amount as alias for total_ron (frontend expects total_amount)
        $inv{total_amount} = $inv{total_ron};
        \%inv;
    } @invoices;

    return { success => 1, data => { invoices => \@data } };
};

get '/next-number' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $number = $invoice_gen->get_next_invoice_number();
    return { success => 1, data => { next_number => $number } };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('Invoice')->find(route_parameters->get('id'), {
        prefetch => ['tenant', 'items'],
    });
    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    my %data = $invoice->get_columns;
    $data{tenant} = $invoice->tenant ? { $invoice->tenant->get_columns } : undef;
    $data{items} = [ map { { $_->get_columns } } $invoice->items->all ];

    return { success => 1, data => { invoice => \%data } };
};

post '/rent' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $data = request->data;

    unless ($data->{tenant_id}) {
        status 400;
        return { success => 0, error => 'tenant_id is required' };
    }

    # Validate tenant exists
    my $tenant = schema->resultset('Tenant')->find($data->{tenant_id});
    unless ($tenant) {
        status 404;
        return { success => 0, error => 'Tenant not found' };
    }

    # Validate date format if provided
    if ($data->{invoice_date} && $data->{invoice_date} !~ /^\d{4}-\d{2}-\d{2}$/) {
        status 400;
        return { success => 0, error => 'Invalid invoice_date format (use YYYY-MM-DD)' };
    }

    if ($data->{due_date} && $data->{due_date} !~ /^\d{4}-\d{2}-\d{2}$/) {
        status 400;
        return { success => 0, error => 'Invalid due_date format (use YYYY-MM-DD)' };
    }

    # Validate period_month if provided
    if (defined $data->{period_month}) {
        unless ($data->{period_month} =~ /^\d+$/ && $data->{period_month} >= 1 && $data->{period_month} <= 12) {
            status 400;
            return { success => 0, error => 'period_month must be between 1 and 12' };
        }
    }

    # Validate period_year if provided
    if (defined $data->{period_year}) {
        unless ($data->{period_year} =~ /^\d{4}$/) {
            status 400;
            return { success => 0, error => 'period_year must be a 4-digit year' };
        }
    }

    # Validate exchange_rate if provided
    if (defined $data->{exchange_rate}) {
        unless ($data->{exchange_rate} =~ /^\d+(\.\d+)?$/ && $data->{exchange_rate} > 0) {
            status 400;
            return { success => 0, error => 'exchange_rate must be a positive number' };
        }
    }

    # Validate additional_items if provided
    if (defined $data->{additional_items}) {
        unless (ref $data->{additional_items} eq 'ARRAY') {
            status 400;
            return { success => 0, error => 'additional_items must be an array' };
        }

        foreach my $item (@{$data->{additional_items}}) {
            unless ($item->{description} && defined $item->{unit_price}) {
                status 400;
                return { success => 0, error => 'Each additional item must have description and unit_price' };
            }
        }
    }

    my ($invoice, $error);
    try {
        $invoice = $invoice_gen->create_rent_invoice(%$data);
    } catch {
        $error = $_;
        error("Failed to create rent invoice: $error");
    };

    if ($error) {
        # Check if this is an exchange rate error that requires user input
        if ($error =~ /EXCHANGE_RATE_REQUIRED:/) {
            status 400;
            my $msg = $error;
            $msg =~ s/^EXCHANGE_RATE_REQUIRED:\s*//;
            return {
                success => 0,
                error => $msg,
                error_code => 'EXCHANGE_RATE_REQUIRED'
            };
        }

        status 500;
        return { success => 0, error => "Failed to create invoice: $error" };
    }

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

post '/utility' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $data = request->data;

    unless ($data->{tenant_id} && $data->{calculation_id}) {
        status 400;
        return { success => 0, error => 'tenant_id and calculation_id are required' };
    }

    my ($invoice, $error);
    try {
        $invoice = $invoice_gen->create_utility_invoice(%$data);
    } catch {
        $error = $_;
        error("Failed to create utility invoice: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => "Failed to create invoice: $error" };
    }

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

post '/generic' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $data = request->data;

    # Validate required fields
    unless ($data->{items} && ref $data->{items} eq 'ARRAY' && @{$data->{items}}) {
        status 400;
        return { success => 0, error => 'items array is required and must not be empty' };
    }

    # Validate date format if provided
    if ($data->{invoice_date} && $data->{invoice_date} !~ /^\d{4}-\d{2}-\d{2}$/) {
        status 400;
        return { success => 0, error => 'Invalid invoice_date format (use YYYY-MM-DD)' };
    }

    if ($data->{due_date} && $data->{due_date} !~ /^\d{4}-\d{2}-\d{2}$/) {
        status 400;
        return { success => 0, error => 'Invalid due_date format (use YYYY-MM-DD)' };
    }

    # Validate each item
    foreach my $item (@{$data->{items}}) {
        unless ($item->{description}) {
            status 400;
            return { success => 0, error => 'Each item must have a description' };
        }

        unless (defined $item->{unit_price}) {
            status 400;
            return { success => 0, error => 'Each item must have a unit_price' };
        }

        # Validate numeric fields
        if (defined $item->{quantity} && $item->{quantity} !~ /^\d+(\.\d+)?$/) {
            status 400;
            return { success => 0, error => 'quantity must be a positive number' };
        }

        if ($item->{unit_price} !~ /^-?\d+(\.\d+)?$/) {
            status 400;
            return { success => 0, error => 'unit_price must be a number' };
        }

        if (defined $item->{vat_rate}) {
            unless ($item->{vat_rate} =~ /^\d+(\.\d+)?$/ && $item->{vat_rate} >= 0 && $item->{vat_rate} <= 100) {
                status 400;
                return { success => 0, error => 'vat_rate must be between 0 and 100' };
            }
        }
    }

    my ($invoice, $error);
    try {
        $invoice = $invoice_gen->create_generic_invoice(%$data);
    } catch {
        $error = $_;
        error("Failed to create generic invoice: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => "Failed to create invoice: $error" };
    }

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

get '/:id/pdf' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = var('user');
    my $invoice_id = route_parameters->get('id');
    my $invoice = schema->resultset('Invoice')->find($invoice_id);

    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    my ($pdf_data, $error);
    try {
        # Use HTML-based PDF generation for better design and Romanian character support
        $pdf_data = $pdf_gen->generate_invoice_pdf_html($invoice_id, user => $user);
    } catch {
        $error = $_;
        error("PDF generation failed: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'PDF generation failed' };
    }

    # Bypass JSON serializer using send_file with scalar ref for in-memory content
    send_file \$pdf_data, content_type => 'application/pdf',
        filename => $invoice->invoice_number . '.pdf';
};

post '/:id/mark-paid' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('Invoice')->find(route_parameters->get('id'));
    return { success => 0, error => 'Invoice not found' } unless $invoice;

    # Prevent marking already paid invoice
    if ($invoice->is_paid) {
        status 400;
        return { success => 0, error => 'Invoice is already marked as paid' };
    }

    my $paid_date = request->data->{paid_date} || DateTime->now->ymd;

    # Use transaction to ensure both invoice and company balance are updated atomically
    my $error;
    try {
        schema->txn_do(sub {
            # Mark invoice as paid
            $invoice->update({ is_paid => 1, paid_date => $paid_date });

            # Update company balance (ADD the invoice total)
            my $company = schema->resultset('Company')->find(1);
            if ($company) {
                my $new_balance = $company->balance + $invoice->total_ron;
                $company->update({ balance => $new_balance });
            }
        });
    } catch {
        $error = $_;
        error("Failed to mark invoice as paid: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to mark invoice as paid' };
    }

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

post '/:id/items' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('Invoice')->find(route_parameters->get('id'));
    return { success => 0, error => 'Invoice not found' } unless $invoice;

    my $data = request->data;

    my ($item, $error);
    try {
        $item = $invoice_gen->add_item(invoice_id => $invoice->id, %$data);
        $invoice_gen->calculate_totals($invoice->id);
    } catch {
        $error = $_;
        error("Failed to add item: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to add item' };
    }

    return { success => 1, data => { item => { $item->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('Invoice')->find(route_parameters->get('id'));
    return { success => 0, error => 'Invoice not found' } unless $invoice;

    if ($invoice->is_paid) {
        status 400;
        return { success => 0, error => 'Cannot delete paid invoice' };
    }

    $invoice->delete;
    return { success => 1, message => 'Invoice deleted' };
};

1;
