package PropertyManager::Routes::Invoices;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf get_current_user);
use PropertyManager::Services::InvoiceGenerator;
use PropertyManager::Services::BNRExchangeRate;
use PropertyManager::Services::PDFGenerator;
use PropertyManager::Services::ActivityLogger;
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

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

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

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_create(
        schema(),
        'invoice',
        $invoice->id,
        sprintf('Factură #%s - %s', $invoice->invoice_number, $tenant->name),
        sprintf('Factură chirie emisă: %s pentru %s, suma %.2f RON',
            $invoice->invoice_number, $tenant->name, $invoice->total_ron),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

post '/utility' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;

    unless ($data->{tenant_id} && $data->{calculation_id}) {
        status 400;
        return { success => 0, error => 'tenant_id and calculation_id are required' };
    }

    my $tenant = schema->resultset('Tenant')->find($data->{tenant_id});
    my $tenant_name = $tenant ? $tenant->name : 'Client';

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

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_create(
        schema(),
        'invoice',
        $invoice->id,
        sprintf('Factură #%s - %s', $invoice->invoice_number, $tenant_name),
        sprintf('Factură utilități emisă: %s pentru %s, suma %.2f RON',
            $invoice->invoice_number, $tenant_name, $invoice->total_ron),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

post '/generic' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

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

    # Log activity
    my $user = get_current_user();
    my $client = $data->{client_name} || 'Client';
    PropertyManager::Services::ActivityLogger::log_create(
        schema(),
        'invoice',
        $invoice->id,
        sprintf('Factură #%s - %s', $invoice->invoice_number, $client),
        sprintf('Factură generică emisă: %s pentru %s, suma %.2f RON',
            $invoice->invoice_number, $client, $invoice->total_ron),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

my @ROMANIAN_MONTHS = qw(
    Ianuarie Februarie Martie Aprilie Mai Iunie
    Iulie August Septembrie Octombrie Noiembrie Decembrie
);

# Sanitize filename by replacing Romanian diacritics with ASCII equivalents
sub _sanitize_filename {
    my ($str) = @_;
    return '' unless defined $str;

    # Replace Romanian diacritics with ASCII equivalents
    $str =~ s/ă/a/g;
    $str =~ s/Ă/A/g;
    $str =~ s/â/a/g;
    $str =~ s/Â/A/g;
    $str =~ s/î/i/g;
    $str =~ s/Î/I/g;
    $str =~ s/ș/s/g;
    $str =~ s/Ș/S/g;
    $str =~ s/ț/t/g;
    $str =~ s/Ț/T/g;

    # Also handle the older cedilla variants
    $str =~ s/ş/s/g;
    $str =~ s/Ş/S/g;
    $str =~ s/ţ/t/g;
    $str =~ s/Ţ/T/g;

    # Remove any other non-ASCII characters
    $str =~ s/[^\x00-\x7F]//g;

    return $str;
}

get '/:id/pdf' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = var('user');
    my $invoice_id = route_parameters->get('id');
    my $invoice = schema->resultset('Invoice')->find($invoice_id, {
        prefetch => ['tenant'],
    });

    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    my ($pdf_data, $error);
    try {
        $pdf_data = $pdf_gen->generate_invoice_pdf_html($invoice_id, user => $user);
    } catch {
        $error = $_;
        error("PDF generation failed: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'PDF generation failed' };
    }

    # Build filename based on invoice type
    # Format: <number without prefix> - <type> <tenant name> <month> <year>.pdf
    my $invoice_number = $invoice->invoice_number;
    my $number_only = $invoice_number;
    $number_only =~ s/^[A-Z]+\s*//;  # Remove prefix (e.g., "ARC 123" -> "123")

    my $tenant_name = $invoice->tenant ? $invoice->tenant->name : ($invoice->client_name || 'Client');

    my ($period_month, $period_year);

    if ($invoice->invoice_type eq 'utility' && $invoice->calculation_id) {
        my $calculation = schema->resultset('UtilityCalculation')->find($invoice->calculation_id);
        if ($calculation) {
            $period_month = $calculation->period_month;
            $period_year = $calculation->period_year;
        }
    }

    # Fallback to invoice date if no calculation period found
    unless ($period_month && $period_year) {
        if ($invoice->invoice_date =~ /^(\d{4})-(\d{2})-/) {
            $period_year = $1;
            $period_month = int($2);
        }
    }

    my $month_name = $ROMANIAN_MONTHS[$period_month - 1] if $period_month;

    # Sanitize tenant name for use in filename (remove diacritics)
    my $safe_tenant_name = _sanitize_filename($tenant_name);

    my $filename;
    my $invoice_type = $invoice->invoice_type || '';

    if ($invoice_type eq 'rent') {
        $filename = "$number_only - chirie $safe_tenant_name $month_name $period_year.pdf";
    } elsif ($invoice_type eq 'utility') {
        $filename = "$number_only - chelt. utilitati $safe_tenant_name $month_name $period_year.pdf";
    } else {
        $filename = "$invoice_number.pdf";
    }

    # Write PDF to temp file and serve with custom filename
    use File::Temp qw(tempfile);
    my ($fh, $tempfile) = tempfile(SUFFIX => '.pdf', UNLINK => 1);
    binmode($fh);
    print $fh $pdf_data;
    close($fh);

    return send_file($tempfile,
        content_type => 'application/pdf',
        filename     => $filename,
        system_path  => 1,
    );
};

post '/:id/mark-paid' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $invoice = schema->resultset('Invoice')->find(route_parameters->get('id'), { prefetch => 'tenant' });
    return { success => 0, error => 'Invoice not found' } unless $invoice;

    # Prevent marking already paid invoice
    if ($invoice->is_paid) {
        status 400;
        return { success => 0, error => 'Invoice is already marked as paid' };
    }

    my $paid_date = request->data->{paid_date} || DateTime->now->ymd;
    my $client_name = $invoice->tenant ? $invoice->tenant->name : ($invoice->client_name || 'Client');

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

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_payment(
        schema(),
        'invoice',
        $invoice->id,
        sprintf('Factură #%s - %s', $invoice->invoice_number, $client_name),
        sprintf('Plată primită pentru factura %s de la %s: %.2f RON',
            $invoice->invoice_number, $client_name, $invoice->total_ron),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

post '/:id/items' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

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

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $invoice = schema->resultset('Invoice')->find(route_parameters->get('id'), { prefetch => 'tenant' });
    return { success => 0, error => 'Invoice not found' } unless $invoice;

    if ($invoice->is_paid) {
        status 400;
        return { success => 0, error => 'Cannot delete paid invoice' };
    }

    # Store info for logging before delete
    my $invoice_number = $invoice->invoice_number;
    my $client_name = $invoice->tenant ? $invoice->tenant->name : ($invoice->client_name || 'Client');
    my $invoice_id = $invoice->id;

    $invoice->delete;

    # Log activity
    my $user = get_current_user();
    PropertyManager::Services::ActivityLogger::log_delete(
        schema(),
        'invoice',
        $invoice_id,
        sprintf('Factură #%s - %s', $invoice_number, $client_name),
        sprintf('Factură ștearsă: %s pentru %s', $invoice_number, $client_name),
        $user ? $user->{id} : undef,
        request->address
    );

    return { success => 1, message => 'Invoice deleted' };
};

1;
