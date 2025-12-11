package PropertyManager::Services::Reports;

use strict;
use warnings;
use Try::Tiny;

=head1 NAME

PropertyManager::Services::Reports - Reporting service

=cut

sub new {
    my ($class, %args) = @_;
    die "schema is required" unless $args{schema};
    return bless \%args, $class;
}

=head2 invoices_report

Generate invoices report with filters.

=cut

sub invoices_report {
    my ($self, %filters) = @_;

    my $search = {};
    my $opts = {
        order_by => { -desc => 'invoice_date' },
        prefetch => 'tenant',
    };

    # Apply filters
    if ($filters{start_date}) {
        $search->{invoice_date} ||= {};
        $search->{invoice_date}{'>='} = $filters{start_date};
    }

    if ($filters{end_date}) {
        $search->{invoice_date} ||= {};
        $search->{invoice_date}{'<='} = $filters{end_date};
    }

    if ($filters{tenant_id}) {
        $search->{tenant_id} = $filters{tenant_id};
    }

    if (defined $filters{invoice_type}) {
        $search->{invoice_type} = $filters{invoice_type};
    }

    if (defined $filters{is_paid}) {
        $search->{is_paid} = $filters{is_paid};
    }

    my @invoices = $self->{schema}->resultset('Invoice')->search(
        $search,
        $opts
    )->all;

    my $total_amount = 0;
    my $paid_amount = 0;
    my $unpaid_amount = 0;

    my @data = map {
        my $amount = $_->total_ron;
        $total_amount += $amount;
        if ($_->is_paid) {
            $paid_amount += $amount;
        } else {
            $unpaid_amount += $amount;
        }

        {
            id => $_->id,
            invoice_number => $_->invoice_number,
            invoice_type => $_->invoice_type,
            tenant_name => $_->tenant->name,
            invoice_date => $_->invoice_date->ymd,
            due_date => $_->due_date->ymd,
            total => sprintf("%.2f", $amount),
            is_paid => $_->is_paid ? 1 : 0,
            paid_date => $_->paid_date ? $_->paid_date->ymd : undef,
        }
    } @invoices;

    return {
        invoices => \@data,
        count => scalar(@invoices),
        totals => {
            total => sprintf("%.2f", $total_amount),
            paid => sprintf("%.2f", $paid_amount),
            unpaid => sprintf("%.2f", $unpaid_amount),
        },
    };
}

=head2 payments_report

Generate payments report.

=cut

sub payments_report {
    my ($self, %filters) = @_;

    my $search = { is_paid => 1 };
    my $opts = {
        order_by => { -desc => 'paid_date' },
        prefetch => 'tenant',
    };

    if ($filters{start_date}) {
        $search->{paid_date} ||= {};
        $search->{paid_date}{'>='} = $filters{start_date};
    }

    if ($filters{end_date}) {
        $search->{paid_date} ||= {};
        $search->{paid_date}{'<='} = $filters{end_date};
    }

    my @payments = $self->{schema}->resultset('Invoice')->search(
        $search,
        $opts
    )->all;

    my $total_paid = 0;
    my @data = map {
        $total_paid += $_->total_ron;
        {
            invoice_number => $_->invoice_number,
            tenant_name => $_->tenant->name,
            paid_date => $_->paid_date->ymd,
            amount => sprintf("%.2f", $_->total_ron),
        }
    } @payments;

    return {
        payments => \@data,
        count => scalar(@payments),
        total => sprintf("%.2f", $total_paid),
    };
}

=head2 tenant_report

Generate detailed report for a specific tenant.

=cut

sub tenant_report {
    my ($self, $tenant_id, %filters) = @_;

    my $tenant = $self->{schema}->resultset('Tenant')->find($tenant_id)
        or die "Tenant not found";

    # Get tenant invoices
    my $search = { tenant_id => $tenant_id };

    if ($filters{start_date}) {
        $search->{invoice_date} ||= {};
        $search->{invoice_date}{'>='} = $filters{start_date};
    }

    if ($filters{end_date}) {
        $search->{invoice_date} ||= {};
        $search->{invoice_date}{'<='} = $filters{end_date};
    }

    my @invoices = $self->{schema}->resultset('Invoice')->search(
        $search,
        { order_by => { -desc => 'invoice_date' } }
    )->all;

    my $total = 0;
    my $paid = 0;
    my $unpaid = 0;

    my @invoice_data = map {
        my $amount = $_->total_ron;
        $total += $amount;
        if ($_->is_paid) {
            $paid += $amount;
        } else {
            $unpaid += $amount;
        }

        {
            invoice_number => $_->invoice_number,
            invoice_type => $_->invoice_type,
            invoice_date => $_->invoice_date->ymd,
            due_date => $_->due_date->ymd,
            total => sprintf("%.2f", $amount),
            is_paid => $_->is_paid ? 1 : 0,
        }
    } @invoices;

    return {
        tenant => {
            id => $tenant->id,
            name => $tenant->name,
            email => $tenant->email,
            rent_amount_eur => sprintf("%.2f", $tenant->rent_amount_eur),
        },
        invoices => \@invoice_data,
        summary => {
            total_invoices => scalar(@invoices),
            total_amount => sprintf("%.2f", $total),
            paid_amount => sprintf("%.2f", $paid),
            unpaid_amount => sprintf("%.2f", $unpaid),
        },
    };
}

1;

__END__

=head1 DESCRIPTION

This service generates various reports with filtering capabilities.

=head1 AUTHOR

Property Management System

=cut
