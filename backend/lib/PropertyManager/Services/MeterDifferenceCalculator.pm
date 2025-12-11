package PropertyManager::Services::MeterDifferenceCalculator;

use strict;
use warnings;
use Try::Tiny;

=head1 NAME

PropertyManager::Services::MeterDifferenceCalculator - Electricity meter difference calculator

=head1 SYNOPSIS

  use PropertyManager::Services::MeterDifferenceCalculator;

  my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

  my $result = $calc->calculate_difference(2025, 12);
  # Returns: {
  #   general_consumption => 1500.00,
  #   tenant_meters_total => 1200.00,
  #   difference => 300.00,
  #   tenant_meters => [...],
  # }

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};

    return bless \%args, $class;
}

=head2 calculate_difference

Calculate the difference between General meter and sum of tenant meters.
Formula: Difference = General consumption - Sum(tenant meters consumption)

Returns hashref with breakdown.

=cut

sub calculate_difference {
    my ($self, $year, $month) = @_;

    die "year and month are required" unless defined $year && defined $month;

    # Get the General meter
    my $general_meter = $self->{schema}->resultset('ElectricityMeter')->search(
        { is_general => 1, is_active => 1 }
    )->first;

    unless ($general_meter) {
        die "General meter not found or inactive";
    }

    # Get General meter reading for this period
    my $general_reading = $self->{schema}->resultset('MeterReading')->search(
        {
            meter_id => $general_meter->id,
            period_year => $year,
            period_month => $month,
        }
    )->first;

    my $general_consumption = $general_reading ? $general_reading->consumption || 0 : 0;

    # Get all tenant meter readings for this period
    my @tenant_meters = $self->{schema}->resultset('ElectricityMeter')->search(
        {
            is_general => 0,
            is_active => 1,
        }
    )->all;

    my @tenant_meter_data;
    my $tenant_total = 0;

    foreach my $meter (@tenant_meters) {
        my $reading = $self->{schema}->resultset('MeterReading')->search(
            {
                meter_id => $meter->id,
                period_year => $year,
                period_month => $month,
            }
        )->first;

        my $consumption = $reading ? $reading->consumption || 0 : 0;
        $tenant_total += $consumption;

        push @tenant_meter_data, {
            meter_id => $meter->id,
            meter_name => $meter->name,
            tenant_id => $meter->tenant_id,
            consumption => sprintf("%.2f", $consumption),
        };
    }

    my $difference = $general_consumption - $tenant_total;

    return {
        general_meter_id => $general_meter->id,
        general_consumption => sprintf("%.2f", $general_consumption),
        tenant_meters_total => sprintf("%.2f", $tenant_total),
        difference => sprintf("%.2f", $difference),
        tenant_meters => \@tenant_meter_data,
        period_month => $month,
        period_year => $year,
    };
}

1;

__END__

=head1 DESCRIPTION

This service calculates the electricity consumption difference between the
General meter (main distribution) and the sum of all tenant meters. This
difference represents common area usage or system losses.

=head1 BUSINESS LOGIC

The General meter measures total property electricity consumption.
Each tenant has individual meters measuring their specific consumption.
The difference (General - Sum of tenant meters) represents:
- Common area consumption (hallways, exterior lights, etc.)
- System losses
- Unmetered areas

This difference is typically absorbed by the property owner (company portion).

=head1 AUTHOR

Property Management System

=cut
