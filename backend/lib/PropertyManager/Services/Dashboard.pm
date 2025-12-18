package PropertyManager::Services::Dashboard;

use strict;
use warnings;
use utf8;
use Try::Tiny;
use List::Util qw(sum);

# Romanian translations for invoice types
my %INVOICE_TYPE_RO = (
    rent => 'chirie',
    utility => 'utilități',
    utilities => 'utilități',
    other => 'altele',
    generic => 'generic',
);

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

=head2 get_tenant_balances

Get balance summary for all active tenants.

=cut

sub get_tenant_balances {
    my ($self) = @_;

    my @tenants = $self->{schema}->resultset('Tenant')->search(
        { is_active => 1 },
        { order_by => 'name' }
    )->all;

    my @balances;
    my $total_receivable = 0;
    my $total_paid = 0;

    foreach my $tenant (@tenants) {
        # Get all invoices for this tenant
        my $invoices_total = $self->{schema}->resultset('Invoice')->search(
            { tenant_id => $tenant->id }
        )->get_column('total_ron')->sum || 0;

        my $invoices_paid = $self->{schema}->resultset('Invoice')->search(
            { tenant_id => $tenant->id, is_paid => 1 }
        )->get_column('total_ron')->sum || 0;

        my $balance = $invoices_total - $invoices_paid;

        my $unpaid_count = $self->{schema}->resultset('Invoice')->search(
            { tenant_id => $tenant->id, is_paid => 0 }
        )->count;

        # Get oldest unpaid invoice date
        my $oldest_unpaid = $self->{schema}->resultset('Invoice')->search(
            { tenant_id => $tenant->id, is_paid => 0 },
            { order_by => 'invoice_date', rows => 1 }
        )->first;

        push @balances, {
            tenant_id => $tenant->id,
            tenant_name => $tenant->name,
            total_invoiced => sprintf("%.2f", $invoices_total),
            total_paid => sprintf("%.2f", $invoices_paid),
            balance => sprintf("%.2f", $balance),
            unpaid_count => $unpaid_count,
            oldest_unpaid_date => $oldest_unpaid ? $oldest_unpaid->invoice_date . '' : undef,
        };

        $total_receivable += $balance if $balance > 0;
        $total_paid += $invoices_paid;
    }

    return {
        tenants => \@balances,
        summary => {
            total_receivable => sprintf("%.2f", $total_receivable),
            total_paid => sprintf("%.2f", $total_paid),
            tenants_with_balance => scalar(grep { $_->{balance} > 0 } @balances),
        },
    };
}

=head2 get_overdue_invoices

Get list of overdue invoices with aging information.

=cut

sub get_overdue_invoices {
    my ($self) = @_;

    my $today = DateTime->now->ymd;

    my @overdue = $self->{schema}->resultset('Invoice')->search(
        {
            is_paid => 0,
            due_date => { '<' => $today },
        },
        {
            order_by => 'due_date',
            prefetch => 'tenant',
        }
    )->all;

    my @data;
    my $total_overdue = 0;

    foreach my $invoice (@overdue) {
        my $due_date = $invoice->due_date;
        my $days_overdue = 0;

        if ($due_date) {
            my ($y, $m, $d) = split('-', $due_date);
            my $due_dt = DateTime->new(year => $y, month => $m, day => $d);
            $days_overdue = DateTime->now->delta_days($due_dt)->in_units('days');
        }

        # Aging bucket
        my $aging_bucket = $days_overdue <= 30 ? '1-30'
                        : $days_overdue <= 60 ? '31-60'
                        : $days_overdue <= 90 ? '61-90'
                        : '90+';

        push @data, {
            id => $invoice->id,
            invoice_number => $invoice->invoice_number,
            tenant_name => $invoice->tenant ? $invoice->tenant->name : 'N/A',
            tenant_id => $invoice->tenant_id,
            total_ron => sprintf("%.2f", $invoice->total_ron),
            invoice_date => $invoice->invoice_date . '',
            due_date => $due_date . '',
            days_overdue => $days_overdue,
            aging_bucket => $aging_bucket,
        };

        $total_overdue += $invoice->total_ron;
    }

    # Summary by aging bucket
    my %aging_summary;
    foreach my $inv (@data) {
        $aging_summary{$inv->{aging_bucket}} ||= { count => 0, total => 0 };
        $aging_summary{$inv->{aging_bucket}}{count}++;
        $aging_summary{$inv->{aging_bucket}}{total} += $inv->{total_ron};
    }

    return {
        invoices => \@data,
        total_overdue => sprintf("%.2f", $total_overdue),
        count => scalar(@data),
        aging_summary => \%aging_summary,
    };
}

=head2 get_utility_cost_evolution

Get utility costs evolution over time by type.

=cut

sub get_utility_cost_evolution {
    my ($self, %params) = @_;

    my $months = $params{months} || 12;

    my %romanian_months = (
        1 => 'Ian', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr',
        5 => 'Mai', 6 => 'Iun', 7 => 'Iul', 8 => 'Aug',
        9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec',
    );

    my @data;
    my $dt = DateTime->now;

    for (my $i = 0; $i < $months; $i++) {
        my $month_start = $dt->clone->truncate(to => 'month')->ymd;
        my $month_end = $dt->clone->add(months => 1)->truncate(to => 'month')->subtract(days => 1)->ymd;

        my %month_data = (
            month => sprintf("%s %d", $romanian_months{$dt->month}, $dt->year),
            month_key => sprintf("%04d-%02d", $dt->year, $dt->month),
        );

        # Get costs by utility type
        my @invoices = $self->{schema}->resultset('ReceivedInvoice')->search(
            {
                'me.period_start' => { '>=' => $month_start, '<=' => $month_end },
            }
        )->all;

        my %by_type;
        foreach my $inv (@invoices) {
            my $type = $inv->utility_type || 'other';
            $by_type{$type} ||= 0;
            $by_type{$type} += $inv->amount;
        }

        $month_data{electricity} = sprintf("%.2f", $by_type{electricity} || 0);
        $month_data{gas} = sprintf("%.2f", $by_type{gas} || 0);
        $month_data{water} = sprintf("%.2f", $by_type{water} || 0);
        $month_data{internet} = sprintf("%.2f", $by_type{internet} || 0);
        $month_data{salubrity} = sprintf("%.2f", $by_type{salubrity} || 0);
        $month_data{other} = sprintf("%.2f", $by_type{other} || 0);
        $month_data{total} = sprintf("%.2f", sum(values %by_type) || 0);

        unshift @data, \%month_data;
        $dt->subtract(months => 1);
    }

    return \@data;
}

=head2 get_due_dates_calendar

Get all due dates for calendar view.

=cut

sub get_due_dates_calendar {
    my ($self, %params) = @_;

    my $start_date = $params{start_date} || DateTime->now->truncate(to => 'month')->ymd;
    my $end_date = $params{end_date} || DateTime->now->add(months => 2)->truncate(to => 'month')->ymd;

    my @events;

    # Received invoices (to pay)
    my @received = $self->{schema}->resultset('ReceivedInvoice')->search(
        {
            due_date => { '>=' => $start_date, '<=' => $end_date },
        },
        { prefetch => 'provider' }
    )->all;

    foreach my $inv (@received) {
        push @events, {
            id => 'received_' . $inv->id,
            type => 'expense',
            title => ($inv->provider ? $inv->provider->name : 'Furnizor') . ' - ' . $inv->invoice_number,
            date => $inv->due_date . '',
            amount => sprintf("%.2f", $inv->amount),
            is_paid => $inv->is_paid ? 1 : 0,
            utility_type => $inv->utility_type,
            entity_type => 'received_invoice',
            entity_id => $inv->id,
        };
    }

    # Issued invoices (to collect)
    my @issued = $self->{schema}->resultset('Invoice')->search(
        {
            due_date => { '>=' => $start_date, '<=' => $end_date },
        },
        { prefetch => 'tenant' }
    )->all;

    foreach my $inv (@issued) {
        push @events, {
            id => 'issued_' . $inv->id,
            type => 'income',
            title => ($inv->tenant ? $inv->tenant->name : 'Chiriaș') . ' - ' . $inv->invoice_number,
            date => $inv->due_date . '',
            amount => sprintf("%.2f", $inv->total_ron),
            is_paid => $inv->is_paid ? 1 : 0,
            invoice_type => $inv->invoice_type,
            entity_type => 'invoice',
            entity_id => $inv->id,
        };
    }

    # Sort by date
    @events = sort { $a->{date} cmp $b->{date} } @events;

    return \@events;
}

=head2 get_collection_report

Get collection report data for a period.

=cut

sub get_collection_report {
    my ($self, %params) = @_;

    my $year = $params{year} || DateTime->now->year;
    my $month = $params{month};  # Optional, if not provided, full year

    my $start_date;
    my $end_date;

    if ($month) {
        $start_date = sprintf("%04d-%02d-01", $year, $month);
        my $dt = DateTime->new(year => $year, month => $month, day => 1);
        $end_date = $dt->add(months => 1)->subtract(days => 1)->ymd;
    } else {
        $start_date = "$year-01-01";
        $end_date = "$year-12-31";
    }

    # Invoices issued in period
    my $issued_total = $self->{schema}->resultset('Invoice')->search(
        { invoice_date => { '>=' => $start_date, '<=' => $end_date } }
    )->get_column('total_ron')->sum || 0;

    my $issued_count = $self->{schema}->resultset('Invoice')->search(
        { invoice_date => { '>=' => $start_date, '<=' => $end_date } }
    )->count;

    # Payments received in period (by paid_date)
    my $collected_total = $self->{schema}->resultset('Invoice')->search(
        {
            is_paid => 1,
            paid_date => { '>=' => $start_date, '<=' => $end_date },
        }
    )->get_column('total_ron')->sum || 0;

    my $collected_count = $self->{schema}->resultset('Invoice')->search(
        {
            is_paid => 1,
            paid_date => { '>=' => $start_date, '<=' => $end_date },
        }
    )->count;

    # Breakdown by invoice type
    my %by_type;
    my @invoices = $self->{schema}->resultset('Invoice')->search(
        { invoice_date => { '>=' => $start_date, '<=' => $end_date } }
    )->all;

    foreach my $inv (@invoices) {
        my $type = $inv->invoice_type || 'other';
        $by_type{$type} ||= { issued => 0, collected => 0, count => 0 };
        $by_type{$type}{issued} += $inv->total_ron;
        $by_type{$type}{count}++;
        $by_type{$type}{collected} += $inv->total_ron if $inv->is_paid;
    }

    # Format breakdown
    my @breakdown;
    foreach my $type (sort keys %by_type) {
        push @breakdown, {
            type => $type,
            issued => sprintf("%.2f", $by_type{$type}{issued}),
            collected => sprintf("%.2f", $by_type{$type}{collected}),
            count => $by_type{$type}{count},
            collection_rate => $by_type{$type}{issued} > 0
                ? sprintf("%.1f", ($by_type{$type}{collected} / $by_type{$type}{issued}) * 100)
                : "0.0",
        };
    }

    # Monthly breakdown for year view
    my @monthly;
    if (!$month) {
        for my $m (1..12) {
            my $m_start = sprintf("%04d-%02d-01", $year, $m);
            my $m_dt = DateTime->new(year => $year, month => $m, day => 1);
            my $m_end = $m_dt->clone->add(months => 1)->subtract(days => 1)->ymd;

            my $m_issued = $self->{schema}->resultset('Invoice')->search(
                { invoice_date => { '>=' => $m_start, '<=' => $m_end } }
            )->get_column('total_ron')->sum || 0;

            my $m_collected = $self->{schema}->resultset('Invoice')->search(
                {
                    is_paid => 1,
                    paid_date => { '>=' => $m_start, '<=' => $m_end },
                }
            )->get_column('total_ron')->sum || 0;

            push @monthly, {
                month => $m,
                issued => sprintf("%.2f", $m_issued),
                collected => sprintf("%.2f", $m_collected),
            };
        }
    }

    return {
        period => {
            year => $year,
            month => $month,
            start_date => $start_date,
            end_date => $end_date,
        },
        summary => {
            issued_total => sprintf("%.2f", $issued_total),
            issued_count => $issued_count,
            collected_total => sprintf("%.2f", $collected_total),
            collected_count => $collected_count,
            collection_rate => $issued_total > 0
                ? sprintf("%.1f", ($collected_total / $issued_total) * 100)
                : "0.0",
            outstanding => sprintf("%.2f", $issued_total - $collected_total),
            outstanding_count => $issued_count - $collected_count,
        },
        by_type => \@breakdown,
        monthly => \@monthly,
    };
}

=head2 get_tenant_statement

Get account statement for a specific tenant.

=cut

sub get_tenant_statement {
    my ($self, %params) = @_;

    my $tenant_id = $params{tenant_id} or die "tenant_id required";
    my $start_date = $params{start_date};
    my $end_date = $params{end_date};

    my $tenant = $self->{schema}->resultset('Tenant')->find($tenant_id);
    die "Tenant not found" unless $tenant;

    my $search = { tenant_id => $tenant_id };
    if ($start_date) {
        $search->{invoice_date} = { '>=' => $start_date };
    }
    if ($end_date) {
        $search->{invoice_date}{'-and'} = { '<=' => $end_date } if ref $search->{invoice_date};
        $search->{invoice_date} = { '<=' => $end_date } unless ref $search->{invoice_date};
    }

    my @invoices = $self->{schema}->resultset('Invoice')->search(
        $search,
        { order_by => 'invoice_date' }
    )->all;

    my @transactions;
    my $running_balance = 0;

    foreach my $inv (@invoices) {
        # Invoice entry (debit)
        $running_balance += $inv->total_ron;
        my $invoice_type_ro = $INVOICE_TYPE_RO{$inv->invoice_type || 'other'} || 'altele';
        push @transactions, {
            date => $inv->invoice_date . '',
            type => 'invoice',
            description => "Factură " . $inv->invoice_number . " (" . $invoice_type_ro . ")",
            debit => sprintf("%.2f", $inv->total_ron),
            credit => '',
            balance => sprintf("%.2f", $running_balance),
            invoice_id => $inv->id,
            invoice_number => $inv->invoice_number,
        };

        # Payment entry (credit) if paid
        if ($inv->is_paid && $inv->paid_date) {
            $running_balance -= $inv->total_ron;
            push @transactions, {
                date => $inv->paid_date . '',
                type => 'payment',
                description => "Plată factură " . $inv->invoice_number,
                debit => '',
                credit => sprintf("%.2f", $inv->total_ron),
                balance => sprintf("%.2f", $running_balance),
                invoice_id => $inv->id,
            };
        }
    }

    # Sort by date
    @transactions = sort { $a->{date} cmp $b->{date} || ($a->{type} eq 'invoice' ? -1 : 1) } @transactions;

    # Recalculate running balance after sort
    my $balance = 0;
    foreach my $t (@transactions) {
        if ($t->{debit}) {
            $balance += $t->{debit};
        }
        if ($t->{credit}) {
            $balance -= $t->{credit};
        }
        $t->{balance} = sprintf("%.2f", $balance);
    }

    # Summary
    my $total_invoiced = $self->{schema}->resultset('Invoice')->search(
        { tenant_id => $tenant_id }
    )->get_column('total_ron')->sum || 0;

    my $total_paid = $self->{schema}->resultset('Invoice')->search(
        { tenant_id => $tenant_id, is_paid => 1 }
    )->get_column('total_ron')->sum || 0;

    return {
        tenant => {
            id => $tenant->id,
            name => $tenant->name,
            email => $tenant->email,
            phone => $tenant->phone,
        },
        transactions => \@transactions,
        summary => {
            total_invoiced => sprintf("%.2f", $total_invoiced),
            total_paid => sprintf("%.2f", $total_paid),
            current_balance => sprintf("%.2f", $total_invoiced - $total_paid),
        },
        period => {
            start_date => $start_date,
            end_date => $end_date,
        },
    };
}

1;

__END__

=head1 DESCRIPTION

This service provides aggregated metrics and data for the dashboard.

=head1 AUTHOR

Property Management System

=cut
