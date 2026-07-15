package PropertyManager::Routes::UtilityCalculations;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use PropertyManager::Services::UtilityCalculator;
use PropertyManager::Services::MeterDifferenceCalculator;
use Try::Tiny;
use DateTime;

prefix '/api/utility-calculations';

my ($calculator, $meter_calc);

hook 'before' => sub {
    $calculator ||= PropertyManager::Services::UtilityCalculator->new(schema => schema);
    $meter_calc ||= PropertyManager::Services::MeterDifferenceCalculator->new(schema => schema);
};

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my @calculations = schema->resultset('UtilityCalculation')->search(
        {},
        { order_by => [{ -desc => 'period_year' }, { -desc => 'period_month' }] }
    )->all;

    my @data = map {
        my %calc = $_->get_columns;
        # Count invoices generated for this calculation
        my $invoice_count = schema->resultset('Invoice')->search({
            calculation_id => $_->id
        })->count;
        $calc{invoices_generated} = $invoice_count;
        \%calc;
    } @calculations;

    return { success => 1, data => \@data };
};

get '/preview/:year/:month' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $year = route_parameters->get('year');
    my $month = route_parameters->get('month');

    # Validate month is between 1 and 12
    if ($month < 1 || $month > 12) {
        status 400;
        return { success => 0, error => 'Month must be between 1 and 12' };
    }

    # Validate year is reasonable
    if ($year < 2000 || $year > 2100) {
        status 400;
        return { success => 0, error => 'Year must be between 2000 and 2100' };
    }

    my ($result, $error);
    try {
        $result = $calculator->calculate_shares(
            year => $year,
            month => $month,
        );

        # Add meter difference calculation
        my $meter_diff;
        try {
            $meter_diff = $meter_calc->calculate_difference($year, $month);
        } catch {
            warning("Meter difference calculation failed: $_");
        };

        $result->{meter_difference} = $meter_diff if $meter_diff;
    } catch {
        $error = $_;
        error("Calculation failed: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Calculation failed' };
    }

    return { success => 1, data => { calculation => $result } };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $calc = schema->resultset('UtilityCalculation')->find(route_parameters->get('id'), {
        prefetch => { details => 'tenant' },
    });
    unless ($calc) {
        status 404;
        return { success => 0, error => 'Calculation not found' };
    }

    my %data = $calc->get_columns;
    $data{details} = [
        map {
            my %det = $_->get_columns;
            $det{tenant_name} = $_->tenant->name;
            \%det;
        } $calc->details->all
    ];

    return { success => 1, data => { calculation => \%data } };
};

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;
    my $year = $data->{period_year};
    my $month = $data->{period_month};
    my $overrides = $data->{overrides} || {};

    unless ($year && $month) {
        status 400;
        return { success => 0, error => 'period_year and period_month are required' };
    }

    # Validate month and year
    if ($month < 1 || $month > 12) {
        status 400;
        return { success => 0, error => 'Month must be between 1 and 12' };
    }

    my ($result, $error, $is_finalized_error);
    try {
        schema->txn_do(sub {
            # Check if calculation already exists
            my $existing = schema->resultset('UtilityCalculation')->search({
                period_year => $year,
                period_month => $month,
            })->first;

            if ($existing && $existing->is_finalized) {
                die "Calculation for this period is already finalized\n";
            }

            # Reuse an existing (non-finalized) calculation row so its metered
            # inputs (metered_calculation_inputs, FK ON DELETE CASCADE) survive
            # a re-save; only its details are refreshed. The row must exist
            # BEFORE calculate_shares so the metered branch has a calculation_id
            # to resolve meter-based shares against.
            my $calculation;
            if ($existing) {
                $calculation = $existing;
                schema->resultset('UtilityCalculationDetail')
                    ->search({ calculation_id => $calculation->id })->delete;
            } else {
                $calculation = schema->resultset('UtilityCalculation')->create({
                    period_year => $year,
                    period_month => $month,
                    is_finalized => 0,
                });
            }

            # Calculate shares. calculation_id lets the metered branch look up
            # its inputs; missing inputs are non-fatal for a draft (strict off).
            my $calc_result = $calculator->calculate_shares(
                year           => $year,
                month          => $month,
                calculation_id => $calculation->id,
                overrides      => $overrides,
            );

            # Create details
            foreach my $tenant_share (@{$calc_result->{tenant_shares}}) {
                my $tenant_id = $tenant_share->{tenant_id};

                foreach my $utility_type (keys %{$tenant_share->{utilities}}) {
                    my $util = $tenant_share->{utilities}{$utility_type};

                    schema->resultset('UtilityCalculationDetail')->create({
                        calculation_id => $calculation->id,
                        tenant_id => $tenant_id,
                        utility_type => $utility_type,
                        received_invoice_id => $util->{invoice_id},
                        percentage => $util->{percentage},
                        amount => $util->{amount},
                    });
                }
            }

            $result = { $calculation->get_columns };
        });
    } catch {
        $error = $_;
        $is_finalized_error = ($error =~ /finalized/);
        error("Failed to create calculation: $error");
    };

    if ($error) {
        status($is_finalized_error ? 409 : 500);
        return { success => 0, error => "$error" };
    }

    return { success => 1, data => { calculation => $result } };
};

post '/:id/finalize' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $calc = schema->resultset('UtilityCalculation')->find(route_parameters->get('id'));
    unless ($calc) {
        status 404;
        return { success => 0, error => 'Calculation not found' };
    }

    if ($calc->is_finalized) {
        status 409;
        return { success => 0, error => 'Calculation is already finalized' };
    }

    my ($error, $missing_data);
    try {
        schema->txn_do(sub {
            $calculator->recompute_all_details($calc->id);
            $calc->update({
                is_finalized => 1,
                finalized_at => DateTime->now,
            });
        });
    } catch {
        $error = $_;
        $missing_data = ($error =~ /Missing|references a missing|must be > 0/);
        error("Failed to finalize calculation: $error");
    };

    if ($error) {
        status($missing_data ? 422 : 500);
        return { success => 0, error => "$error" };
    }

    return { success => 1, data => { calculation => { $calc->get_columns } } };
};

1;
