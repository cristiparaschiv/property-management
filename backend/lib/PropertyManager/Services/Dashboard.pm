package PropertyManager::Services::Dashboard;

use strict;
use warnings;
use Try::Tiny;
use List::Util qw(sum);

=head1 NAME

PropertyManager::Services::Dashboard - Dashboard metrics service

=cut

sub new {
    my ($class, %args) = @_;
    die "schema is required" unless $args{schema};
    return bless \%args, $class;
}

=head2 get_summary

Get dashboard summary metrics.

=cut

sub get_summary {
    my ($self) = @_;

    # Get company balance
    my $company = $self->{schema}->resultset('Company')->find(1);
    my $company_balance = $company ? $company->balance : 0;

    # Active tenants count
    my $active_tenants = $self->{schema}->resultset('Tenant')->search(
        { is_active => 1 }
    )->count;

    # Total expected rent (sum of all active tenant rents)
    my $total_expected_rent = $self->{schema}->resultset('Tenant')->search(
        { is_active => 1 }
    )->get_column('rent_amount_eur')->sum || 0;

    # Total unpaid invoices
    my $unpaid_invoices = $self->{schema}->resultset('Invoice')->search(
        { is_paid => 0 }
    );
    my $unpaid_count = $unpaid_invoices->count;
    my $unpaid_total = $unpaid_invoices->get_column('total_ron')->sum || 0;

    # Total paid this month
    my $current_month_start = DateTime->now->truncate(to => 'month')->ymd;
    my $paid_this_month = $self->{schema}->resultset('Invoice')->search(
        {
            is_paid => 1,
            paid_date => { '>=' => $current_month_start },
        }
    )->get_column('total_ron')->sum || 0;

    # Unpaid received invoices (expenses)
    my $unpaid_received = $self->{schema}->resultset('ReceivedInvoice')->search(
        { 'me.is_paid' => 0 }
    );
    my $unpaid_received_count = $unpaid_received->count;
    my $unpaid_received_total = $unpaid_received->get_column('me.amount')->sum || 0;

    # Monthly expenses (current month)
    my $current_month_end = DateTime->now->clone->add(months => 1)->truncate(to => 'month')->subtract(days => 1)->ymd;
    my $monthly_expenses = $self->{schema}->resultset('ReceivedInvoice')->search(
        {
            'me.period_start' => { '>=' => $current_month_start, '<=' => $current_month_end },
        }
    )->get_column('me.amount')->sum || 0;

    # Recent received invoices (last 5)
    my @recent_received = $self->{schema}->resultset('ReceivedInvoice')->search(
        {},
        {
            order_by => { -desc => 'created_at' },
            rows => 5,
        }
    )->all;

    my @recent_received_data = map {
        my $provider = $_->provider;
        {
            id => $_->id,
            provider_name => $provider ? $provider->name : 'N/A',
            utility_type => $_->utility_type,
            amount => sprintf("%.2f", $_->amount),
            period_start => $_->period_start // undef,
            is_paid => $_->is_paid ? 1 : 0,
            due_date => $_->due_date // undef,
        }
    } @recent_received;

    # Upcoming due invoices (unpaid received invoices with due date in next 7 days)
    my $next_week = DateTime->now->add(days => 7)->ymd;
    my @upcoming_due = $self->{schema}->resultset('ReceivedInvoice')->search(
        {
            is_paid => 0,
            due_date => { '<=' => $next_week },
        },
        {
            order_by => { -asc => 'due_date' },
            rows => 5,
        }
    )->all;

    my @upcoming_due_data = map {
        my $provider = $_->provider;
        {
            id => $_->id,
            provider_name => $provider ? $provider->name : 'N/A',
            utility_type => $_->utility_type,
            amount => sprintf("%.2f", $_->amount),
            due_date => $_->due_date // undef,
        }
    } @upcoming_due;

    return {
        company_balance => sprintf("%.2f", $company_balance),
        active_tenants => $active_tenants,
        total_expected_rent => sprintf("%.2f", $total_expected_rent),
        unpaid_invoices => {
            count => $unpaid_count,
            total => sprintf("%.2f", $unpaid_total),
        },
        monthly_expenses => sprintf("%.2f", $monthly_expenses),
        paid_this_month => sprintf("%.2f", $paid_this_month),
        unpaid_received_invoices => {
            count => $unpaid_received_count,
            total => sprintf("%.2f", $unpaid_received_total),
        },
        recent_received_invoices => \@recent_received_data,
        upcoming_due_invoices => \@upcoming_due_data,
    };
}

=head2 get_revenue_chart_data

Get monthly revenue data for charts (last 12 months).

=cut

sub get_revenue_chart_data {
    my ($self, %params) = @_;

    my $months = $params{months} || 12;

    my @data;
    my $dt = DateTime->now;

    for (my $i = 0; $i < $months; $i++) {
        my $month_start = $dt->clone->truncate(to => 'month')->ymd;
        my $month_end = $dt->clone->add(months => 1)->truncate(to => 'month')->subtract(days => 1)->ymd;

        my $revenue = $self->{schema}->resultset('Invoice')->search(
            {
                invoice_date => { '>=' => $month_start, '<=' => $month_end },
                is_paid => 1,
            }
        )->get_column('total_ron')->sum || 0;

        unshift @data, {
            month => $dt->month_name,
            year => $dt->year,
            revenue => sprintf("%.2f", $revenue),
        };

        $dt->subtract(months => 1);
    }

    return \@data;
}

=head2 get_utility_costs_chart_data

Get utility costs breakdown.

=cut

sub get_utility_costs_chart_data {
    my ($self, %params) = @_;

    my $year = $params{year} || DateTime->now->year;
    my $month = $params{month} || DateTime->now->month;

    my $period_start = sprintf("%04d-%02d-01", $year, $month);

    my %costs_by_type;

    my @invoices = $self->{schema}->resultset('ReceivedInvoice')->search(
        {
            'me.period_start' => { '>=' => $period_start },
        }
    )->all;

    foreach my $invoice (@invoices) {
        my $type = $invoice->utility_type;
        $costs_by_type{$type} ||= 0;
        $costs_by_type{$type} += $invoice->amount;
    }

    my @data;
    foreach my $type (sort keys %costs_by_type) {
        push @data, {
            utility_type => $type,
            amount => sprintf("%.2f", $costs_by_type{$type}),
        };
    }

    return \@data;
}

=head2 get_expenses_trend_data

Get monthly expenses trend data for the last N months.

=cut

sub get_expenses_trend_data {
    my ($self, %params) = @_;

    my $months = $params{months} || 6;

    my @data;
    my $dt = DateTime->now;

    for (my $i = 0; $i < $months; $i++) {
        my $month_start = $dt->clone->truncate(to => 'month')->ymd;
        my $month_end = $dt->clone->add(months => 1)->truncate(to => 'month')->subtract(days => 1)->ymd;

        my $expenses = $self->{schema}->resultset('ReceivedInvoice')->search(
            {
                'me.period_start' => { '>=' => $month_start, '<=' => $month_end },
            }
        )->get_column('me.amount')->sum || 0;

        unshift @data, {
            month => $dt->month,
            year => $dt->year,
            expenses => sprintf("%.2f", $expenses),
        };

        $dt->subtract(months => 1);
    }

    return \@data;
}

=head2 get_invoices_status_data

Get invoice status distribution (paid vs unpaid).

=cut

sub get_invoices_status_data {
    my ($self) = @_;

    my $paid_count = $self->{schema}->resultset('Invoice')->search(
        { is_paid => 1 }
    )->count;

    my $unpaid_count = $self->{schema}->resultset('Invoice')->search(
        { is_paid => 0 }
    )->count;

    my $paid_total = $self->{schema}->resultset('Invoice')->search(
        { is_paid => 1 }
    )->get_column('total_ron')->sum || 0;

    my $unpaid_total = $self->{schema}->resultset('Invoice')->search(
        { is_paid => 0 }
    )->get_column('total_ron')->sum || 0;

    return {
        paid => {
            count => $paid_count,
            total => sprintf("%.2f", $paid_total),
        },
        unpaid => {
            count => $unpaid_count,
            total => sprintf("%.2f", $unpaid_total),
        },
    };
}

=head2 get_cash_flow_chart_data

Get monthly cash flow data for the last 12 months.

Returns data with:
- received_payments: Sum of paid invoices by paid_date
- invoices_issued: Sum of all invoices by invoice_date
- payments_made: Sum of paid received invoices by paid_date
- utility_invoices: Sum of all received invoices by invoice_date

=cut

sub get_cash_flow_chart_data {
    my ($self, %params) = @_;

    my $months = $params{months} || 12;

    # Romanian month names
    my %romanian_months = (
        1  => 'Ianuarie',
        2  => 'Februarie',
        3  => 'Martie',
        4  => 'Aprilie',
        5  => 'Mai',
        6  => 'Iunie',
        7  => 'Iulie',
        8  => 'August',
        9  => 'Septembrie',
        10 => 'Octombrie',
        11 => 'Noiembrie',
        12 => 'Decembrie',
    );

    my @data;
    my $dt = DateTime->now;

    for (my $i = 0; $i < $months; $i++) {
        my $month_start = $dt->clone->truncate(to => 'month')->ymd;
        my $month_end = $dt->clone->add(months => 1)->truncate(to => 'month')->subtract(days => 1)->ymd;

        # Received payments: Sum of paid invoices by paid_date
        my $received_payments = $self->{schema}->resultset('Invoice')->search(
            {
                is_paid => 1,
                paid_date => { '>=' => $month_start, '<=' => $month_end },
            }
        )->get_column('total_ron')->sum || 0;

        # Invoices issued: Sum of all invoices by invoice_date
        my $invoices_issued = $self->{schema}->resultset('Invoice')->search(
            {
                invoice_date => { '>=' => $month_start, '<=' => $month_end },
            }
        )->get_column('total_ron')->sum || 0;

        # Payments made: Sum of paid received invoices by paid_date
        my $payments_made = $self->{schema}->resultset('ReceivedInvoice')->search(
            {
                is_paid => 1,
                paid_date => { '>=' => $month_start, '<=' => $month_end },
            }
        )->get_column('amount')->sum || 0;

        # Utility invoices: Sum of all received invoices by invoice_date
        my $utility_invoices = $self->{schema}->resultset('ReceivedInvoice')->search(
            {
                invoice_date => { '>=' => $month_start, '<=' => $month_end },
            }
        )->get_column('amount')->sum || 0;

        # Format month as YYYY-MM
        my $month_key = sprintf("%04d-%02d", $dt->year, $dt->month);
        my $month_name = $romanian_months{$dt->month} . ' ' . $dt->year;

        unshift @data, {
            month => $month_key,
            month_name => $month_name,
            received_payments => sprintf("%.2f", $received_payments),
            invoices_issued => sprintf("%.2f", $invoices_issued),
            payments_made => sprintf("%.2f", $payments_made),
            utility_invoices => sprintf("%.2f", $utility_invoices),
        };

        $dt->subtract(months => 1);
    }

    return \@data;
}

1;

__END__

=head1 DESCRIPTION

This service provides aggregated metrics and data for the dashboard.

=head1 AUTHOR

Property Management System

=cut
