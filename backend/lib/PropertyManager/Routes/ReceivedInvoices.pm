package PropertyManager::Routes::ReceivedInvoices;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use DateTime;
use Try::Tiny;

prefix '/api/received-invoices';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{provider_id} = query_parameters->get('provider_id') if query_parameters->get('provider_id');
    $search->{utility_type} = query_parameters->get('type') if query_parameters->get('type');
    $search->{is_paid} = query_parameters->get('paid') ? 1 : 0 if defined query_parameters->get('paid');

    my @invoices = schema->resultset('ReceivedInvoice')->search($search, {
        order_by => { -desc => 'invoice_date' },
        prefetch => 'provider',
    })->all;

    my @data = map {
        my %inv = $_->get_columns;
        $inv{provider_name} = $_->provider->name;
        \%inv;
    } @invoices;

    return { success => 1, data => \@data };
};

get '/period/:year/:month' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $year = route_parameters->get('year');
    my $month = route_parameters->get('month');

    # Calculate period boundaries
    my $period_start = sprintf("%04d-%02d-01", $year, $month);

    # Last day of month
    my $last_day = 31;
    if ($month == 2) {
        $last_day = ($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0)) ? 29 : 28;
    } elsif ($month == 4 || $month == 6 || $month == 9 || $month == 11) {
        $last_day = 30;
    }
    my $period_end = sprintf("%04d-%02d-%02d", $year, $month, $last_day);

    # Find invoices that overlap with the period
    # An invoice overlaps if: invoice.period_start <= month_end AND invoice.period_end >= month_start
    my @invoices = schema->resultset('ReceivedInvoice')->search(
        {
            period_start => { '<=' => $period_end },
            period_end => { '>=' => $period_start },
        },
        {
            order_by => ['utility_type', 'period_start'],
            prefetch => 'provider',
        }
    )->all;

    my @data = map {
        my %inv = $_->get_columns;
        $inv{provider_name} = $_->provider->name;
        \%inv;
    } @invoices;

    return { success => 1, data => \@data };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('ReceivedInvoice')->find(route_parameters->get('id'), { prefetch => 'provider' });
    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    my %data = $invoice->get_columns;
    $data{provider_name} = $invoice->provider->name;
    return { success => 1, data => { invoice => \%data } };
};

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $data = request->data;
    unless ($data->{provider_id} && $data->{invoice_number} && $data->{invoice_date} &&
            $data->{due_date} && $data->{amount} && $data->{utility_type} &&
            $data->{period_start} && $data->{period_end}) {
        status 400;
        return { success => 0, error => 'Missing required fields' };
    }

    # Validate amount is positive
    if ($data->{amount} < 0) {
        status 400;
        return { success => 0, error => 'Amount must be positive' };
    }

    # Validate provider exists
    my $provider = schema->resultset('UtilityProvider')->find($data->{provider_id});
    unless ($provider) {
        status 404;
        return { success => 0, error => 'Provider not found' };
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    my ($invoice, $error);
    try {
        $invoice = schema->resultset('ReceivedInvoice')->create($data);
    } catch {
        $error = $_;
        error("Failed to create received invoice: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to create invoice' };
    }

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

put '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('ReceivedInvoice')->find(route_parameters->get('id'));
    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    my $data = request->data;

    # Validate amount is positive if provided
    if (exists $data->{amount} && $data->{amount} < 0) {
        status 400;
        return { success => 0, error => 'Amount must be positive' };
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    my $error;
    try {
        $invoice->update($data);
    } catch {
        $error = $_;
        error("Failed to update received invoice: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to update invoice' };
    }

    return { success => 1, data => { invoice => { $invoice->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('ReceivedInvoice')->find(route_parameters->get('id'));
    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    $invoice->delete;
    return { success => 1, message => 'Invoice deleted' };
};

post '/:id/mark-paid' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('ReceivedInvoice')->find(route_parameters->get('id'));
    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

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

            # Update company balance (SUBTRACT the invoice amount)
            my $company = schema->resultset('Company')->find(1);
            if ($company) {
                my $new_balance = $company->balance - $invoice->amount;
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

post '/:id/paid-now' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $invoice = schema->resultset('ReceivedInvoice')->find(route_parameters->get('id'));
    unless ($invoice) {
        status 404;
        return { success => 0, error => 'Invoice not found' };
    }

    # Prevent marking already paid invoice
    if ($invoice->is_paid) {
        status 400;
        return { success => 0, error => 'Invoice is already marked as paid' };
    }

    # Use transaction to ensure both invoice and company balance are updated atomically
    my $error;
    try {
        schema->txn_do(sub {
            # Mark invoice as paid
            $invoice->update({ is_paid => 1, paid_date => DateTime->now->ymd });

            # Update company balance (SUBTRACT the invoice amount)
            my $company = schema->resultset('Company')->find(1);
            if ($company) {
                my $new_balance = $company->balance - $invoice->amount;
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

1;
