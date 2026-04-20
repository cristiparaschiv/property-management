package PropertyManager::Services::UtilityCalculator;

use strict;
use warnings;
use Try::Tiny;
use List::Util qw(sum);

=head1 NAME

PropertyManager::Services::UtilityCalculator - Utility cost calculation service

=head1 SYNOPSIS

  use PropertyManager::Services::UtilityCalculator;

  my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

  # Calculate utility shares for a period
  my $result = $calc->calculate_shares(
      year => 2025,
      month => 12,
      overrides => {  # Optional percentage overrides
          1 => { electricity => 50.00, water => 30.00 },  # tenant_id => { utility_type => percentage }
      }
  );

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};

    return bless \%args, $class;
}

=head2 calculate_shares

Calculate tenant utility shares for a specific period.
Returns hashref with tenant shares and company portion.

=cut

sub calculate_shares {
    my ($self, %params) = @_;

    my $year = $params{year};
    my $month = $params{month};
    my $overrides = $params{overrides} || {};

    die "year and month are required" unless defined $year && defined $month;

    # Resolve the calculation_id for this period (needed for metered branch).
    # Callers may pass it in; otherwise we look it up by period.
    my $calculation_id = $params{calculation_id};
    unless ($calculation_id) {
        my $calc_row = $self->{schema}->resultset('UtilityCalculation')->search(
            { period_year => $year, period_month => $month }
        )->first;
        $calculation_id = $calc_row ? $calc_row->id : undef;
    }

    # Get all received invoices for this period
    my @invoices = $self->get_invoices_for_period($year, $month);

    # Get all active tenants
    my @tenants = $self->{schema}->resultset('Tenant')->search(
        { is_active => 1 }
    )->all;

    # Calculate shares for each utility type
    my %tenant_shares;  # { tenant_id => { utility_type => { amount, percentage, invoice_id } } }
    my %company_portions;  # { utility_type => amount }
    my %invoice_allocations;  # { invoice_id => { tenant_shares, company_portion } }

    foreach my $invoice (@invoices) {
        my $utility_type = $invoice->utility_type;
        my $total_amount = $invoice->amount;
        my $invoice_id = $invoice->id;

        # Resolve each tenant's share (effective percentage + amount).
        # Metered tenants for gas/water take the meter-based branch; everyone
        # else gets the legacy fixed-% path.
        my %tenant_resolved;  # tenant_id => { percentage, amount }
        foreach my $tenant (@tenants) {
            my $tenant_id = $tenant->id;

            my $share;
            if ($overrides->{$tenant_id}
                && defined $overrides->{$tenant_id}{$utility_type}) {
                my $p = $overrides->{$tenant_id}{$utility_type};
                $share = {
                    percentage => $p,
                    amount     => ($total_amount * $p) / 100,
                };
            } else {
                $share = $self->_resolve_tenant_share(
                    tenant_id      => $tenant_id,
                    utility_type   => $utility_type,
                    invoice        => $invoice,
                    year           => $year,
                    month          => $month,
                    calculation_id => $calculation_id,
                );
            }

            $tenant_resolved{$tenant_id} = $share;
        }

        # Sum effective percentages for company-portion math
        my $total_tenant_pct = sum(map { $_->{percentage} } values %tenant_resolved) || 0;

        my $company_pct = 100 - $total_tenant_pct;
        $company_pct = 0 if $company_pct < 0;

        # Emit tenant share records
        my %invoice_tenant_shares;
        foreach my $tenant (@tenants) {
            my $tenant_id = $tenant->id;
            my $share     = $tenant_resolved{$tenant_id};
            my $amount    = $share->{amount} || 0;
            my $percentage = $share->{percentage} || 0;

            next if $amount == 0;

            $tenant_shares{$tenant_id}{$utility_type} = {
                amount => sprintf("%.2f", $amount),
                percentage => sprintf("%.2f", $percentage),
                invoice_id => $invoice_id,
                invoice_number => $invoice->invoice_number,
            };

            $invoice_tenant_shares{$tenant_id} = {
                amount => sprintf("%.2f", $amount),
                percentage => sprintf("%.2f", $percentage),
            };
        }

        # Calculate company portion
        my $company_amount = ($total_amount * $company_pct) / 100;
        $company_portions{$utility_type} ||= 0;
        $company_portions{$utility_type} += $company_amount;

        $invoice_allocations{$invoice_id} = {
            utility_type => $utility_type,
            total_amount => sprintf("%.2f", $total_amount),
            invoice_number => $invoice->invoice_number,
            tenant_shares => \%invoice_tenant_shares,
            company_portion => {
                amount => sprintf("%.2f", $company_amount),
                percentage => sprintf("%.2f", $company_pct),
            },
            total_tenant_percentage => sprintf("%.2f", $total_tenant_pct),
        };
    }

    # Format tenant shares by tenant
    my @tenant_details;
    foreach my $tenant (@tenants) {
        my $tenant_id = $tenant->id;
        my $shares = $tenant_shares{$tenant_id} || {};

        my $total_amount = sum(map { $_->{amount} } values %$shares) || 0;

        push @tenant_details, {
            tenant_id => $tenant_id,
            tenant_name => $tenant->name,
            utilities => $shares,
            total_amount => sprintf("%.2f", $total_amount),
        };
    }

    # Format company portions
    my $company_total = sum(values %company_portions) || 0;
    my @company_details;
    foreach my $utility_type (keys %company_portions) {
        push @company_details, {
            utility_type => $utility_type,
            amount => sprintf("%.2f", $company_portions{$utility_type}),
        };
    }

    return {
        period_month => $month,
        period_year => $year,
        tenant_shares => \@tenant_details,
        company_portion => {
            total => sprintf("%.2f", $company_total),
            by_utility => \@company_details,
        },
        invoice_allocations => \%invoice_allocations,
        total_invoices => scalar(@invoices),
    };
}

=head2 get_invoices_for_period

Get all received invoices that overlap with the specified period.

=cut

sub get_invoices_for_period {
    my ($self, $year, $month) = @_;

    # Calculate period boundaries
    my $period_start = sprintf("%04d-%02d-01", $year, $month);

    # Last day of month
    my $last_day = 31;
    if ($month == 2) {
        # Check for leap year
        $last_day = ($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0)) ? 29 : 28;
    } elsif ($month == 4 || $month == 6 || $month == 9 || $month == 11) {
        $last_day = 30;
    }

    my $period_end = sprintf("%04d-%02d-%02d", $year, $month, $last_day);

    # Find invoices where period overlaps with our target period
    my @invoices = $self->{schema}->resultset('ReceivedInvoice')->search(
        {
            -or => [
                # Invoice period starts within our period
                {
                    -and => [
                        period_start => { '>=' => $period_start },
                        period_start => { '<=' => $period_end },
                    ]
                },
                # Invoice period ends within our period
                {
                    -and => [
                        period_end => { '>=' => $period_start },
                        period_end => { '<=' => $period_end },
                    ]
                },
                # Invoice period encompasses our period
                {
                    -and => [
                        period_start => { '<=' => $period_start },
                        period_end => { '>=' => $period_end },
                    ]
                },
            ]
        },
        {
            order_by => ['utility_type', 'period_start'],
        }
    )->all;

    return @invoices;
}

=head2 _resolve_tenant_share

Resolve a (tenant, utility, invoice) share. Returns a hashref:
  { percentage => <effective % on this invoice>, amount => <RON> }

Non-metered utilities and non-gas/water utilities take the fixed-% path.
Metered gas/water dispatches on meter readings and metered_calculation_inputs.

=cut

sub _resolve_tenant_share {
    my ($self, %args) = @_;
    my ($tenant_id, $utility_type, $invoice, $year, $month, $calculation_id) =
        @args{qw(tenant_id utility_type invoice year month calculation_id)};

    my $pct_record = $self->{schema}->resultset('TenantUtilityPercentage')->search(
        { tenant_id => $tenant_id, utility_type => $utility_type }
    )->first;

    my $fixed_pct  = $pct_record ? $pct_record->percentage : 0;
    my $uses_meter = $pct_record ? $pct_record->uses_meter  : 0;

    # Non-metered OR metered-but-not-gas/water: fall back to fixed-% behavior.
    unless ($uses_meter && ($utility_type eq 'gas' || $utility_type eq 'water')) {
        my $amount = ($invoice->amount * $fixed_pct) / 100;
        return { percentage => $fixed_pct, amount => $amount };
    }

    die "calculation_id required for metered billing" unless $calculation_id;

    my $inputs = $self->{schema}->resultset('MeteredCalculationInput')->search({
        calculation_id => $calculation_id,
        utility_type   => $utility_type,
    })->first;

    die "Missing metered inputs for $utility_type in calculation $calculation_id"
        unless $inputs;

    my $reading_rs = $utility_type eq 'gas' ? 'GasReading' : 'WaterReading';
    my $reading = $self->{schema}->resultset($reading_rs)->search({
        tenant_id    => $tenant_id,
        period_year  => $year,
        period_month => $month,
    })->first;

    die "Missing $utility_type reading for tenant $tenant_id / $year-$month"
        unless $reading;

    my $tenant_units = defined $reading->consumption
        ? $reading->consumption
        : ($reading->reading_value - ($reading->previous_reading_value // 0));

    my $total_units = $inputs->total_units;
    die "total_units must be > 0 for metered $utility_type" unless $total_units > 0;

    if ($utility_type eq 'gas') {
        my $ratio  = $tenant_units / $total_units;
        my $amount = $ratio * $invoice->amount;
        return {
            percentage => $ratio * 100,
            amount     => $amount,
        };
    }

    # water
    my $consumption_amount = $inputs->consumption_amount || 0;
    my $rain_amount        = $inputs->rain_amount || 0;

    my $consumption_share = ($tenant_units / $total_units) * $consumption_amount;
    my $rain_share        = ($fixed_pct / 100) * $rain_amount;
    my $amount            = $consumption_share + $rain_share;
    my $effective_pct     = $invoice->amount > 0
        ? ($amount / $invoice->amount) * 100
        : 0;

    return {
        percentage => $effective_pct,
        amount     => $amount,
    };
}

1;

__END__

=head1 DESCRIPTION

This service calculates how utility costs should be distributed among tenants
based on their configured percentages. It supports:

- Default percentages from tenant_utility_percentages table
- Ad-hoc percentage overrides for specific calculations
- Automatic calculation of company (owner) portion
- Detailed breakdown per invoice, tenant, and utility type

=head1 BUSINESS LOGIC

For each utility invoice:
1. Get total amount
2. For each tenant, apply their percentage (default or override)
3. Calculate tenant share = (amount * percentage / 100)
4. Sum all tenant percentages
5. Company portion percentage = 100% - sum of tenant percentages
6. Company portion amount = (amount * company_pct / 100)

The system ensures all amounts add up to the invoice total.

=head1 PERCENTAGE OVERRIDES

Overrides allow changing percentages for specific calculations without
modifying the tenant's default percentages. This is useful for:
- One-time adjustments
- Testing different allocation scenarios
- Handling vacant periods

=head1 AUTHOR

Property Management System

=cut
