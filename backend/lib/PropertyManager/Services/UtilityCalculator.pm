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
    my $strict = $params{strict} ? 1 : 0;

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
                    strict         => $strict,
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
    my ($tenant_id, $utility_type, $invoice, $year, $month, $calculation_id, $strict) =
        @args{qw(tenant_id utility_type invoice year month calculation_id strict)};

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

    unless ($calculation_id) {
        die "calculation_id required for metered billing\n" if $strict;
        return { percentage => 0, amount => 0 };
    }

    my $inputs = $self->{schema}->resultset('MeteredCalculationInput')->search({
        calculation_id => $calculation_id,
        utility_type   => $utility_type,
    })->first;

    unless ($inputs) {
        die "Missing metered inputs for $utility_type in calculation $calculation_id\n" if $strict;
        return { percentage => 0, amount => 0 };
    }

    my $reading_rs = $utility_type eq 'gas' ? 'GasReading' : 'WaterReading';
    my $reading = $self->{schema}->resultset($reading_rs)->search({
        tenant_id    => $tenant_id,
        period_year  => $year,
        period_month => $month,
    })->first;

    unless ($reading) {
        die "Missing $utility_type reading for tenant $tenant_id / $year-$month\n" if $strict;
        return { percentage => 0, amount => 0 };
    }

    my $tenant_units = defined $reading->consumption
        ? $reading->consumption
        : ($reading->reading_value - ($reading->previous_reading_value // 0));

    my $total_units = $inputs->total_units;
    unless ($total_units > 0) {
        die "total_units must be > 0 for metered $utility_type\n" if $strict;
        return { percentage => 0, amount => 0 };
    }

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

=head2 recompute_all_details

Recompute and rewrite ALL UtilityCalculationDetail rows for a calculation at
finalize time, so the finalized invoice reflects the real configuration
regardless of the order data was entered.

- Metered gas/water pairs are computed from meter readings + inputs (strict:
  a missing reading/input dies so finalize is blocked with a clear message).
- Non-metered pairs reuse any percentage that was persisted at create time
  (preserving ad-hoc per-calc overrides); a non-metered pair with no persisted
  detail falls back to the tenant's stored percentage. This recovers details
  that a stale draft dropped by sending a shadowing `= 0` override.

Known limitations (both narrow; the primary goal is recovering dropped
non-metered details, a common failure, at the cost of these rare cases):

- An *intentional* ad-hoc 0% on a non-metered utility (a 0 that differs from
  the tenant's stored percentage) leaves no persisted detail (amount 0 is not
  stored), so it is indistinguishable from a dropped detail and is recomputed
  from the stored percentage. To bill 0, set the tenant's stored percentage to
  0 (which recomputes to 0 correctly) rather than an ad-hoc per-calc 0.
- A tenant deactivated between create and finalize is excluded from the
  recompute (calculate_shares only sees active tenants), so their details are
  not re-emitted. Deactivated tenants are not invoiced anyway.

=cut

sub recompute_all_details {
    my ($self, $calculation_id) = @_;
    my $schema = $self->{schema};

    my $calc = $schema->resultset('UtilityCalculation')->find($calculation_id)
        or die "Calculation $calculation_id not found\n";

    # Rebuild overrides from the currently-persisted NON-metered details so
    # ad-hoc percentages survive. Metered (gas/water uses_meter) pairs are left
    # out so they recompute from meter readings; non-metered pairs with no
    # persisted detail are left out too, so they fall back to the stored
    # tenant percentage (recovering an electricity/etc. detail a stale draft
    # dropped).
    my %overrides;
    my @details = $schema->resultset('UtilityCalculationDetail')
        ->search({ calculation_id => $calculation_id })->all;
    for my $d (@details) {
        my $up = $schema->resultset('TenantUtilityPercentage')->search({
            tenant_id => $d->tenant_id, utility_type => $d->utility_type,
        })->first;
        next if $up && $up->uses_meter
            && ($d->utility_type eq 'gas' || $d->utility_type eq 'water');
        $overrides{ $d->tenant_id }{ $d->utility_type } = $d->percentage + 0;
    }

    my $result = $self->calculate_shares(
        year           => $calc->period_year,
        month          => $calc->period_month,
        calculation_id => $calculation_id,
        overrides      => \%overrides,
        strict         => 1,
    );

    # Rewrite all details from the fresh result.
    $schema->resultset('UtilityCalculationDetail')
        ->search({ calculation_id => $calculation_id })->delete;

    foreach my $ts (@{ $result->{tenant_shares} }) {
        my $tid = $ts->{tenant_id};
        foreach my $ut (keys %{ $ts->{utilities} }) {
            my $u = $ts->{utilities}{$ut};
            $schema->resultset('UtilityCalculationDetail')->create({
                calculation_id      => $calculation_id,
                tenant_id           => $tid,
                utility_type        => $ut,
                received_invoice_id => $u->{invoice_id},
                percentage          => $u->{percentage},
                amount              => $u->{amount},
            });
        }
    }
    return 1;
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
