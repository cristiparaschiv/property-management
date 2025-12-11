#!/usr/bin/env perl

=head1 NAME

backfill_previous_reading_values.pl - Backfill previous_reading_value for existing meter readings

=head1 SYNOPSIS

  perl bin/backfill_previous_reading_values.pl [--dry-run] [--verbose]

=head1 DESCRIPTION

This script backfills the previous_reading_value column for all existing meter_readings.
It finds the previous period's reading for each meter reading and stores that value.

This script should be run after adding the previous_reading_value column via migration.

=head1 OPTIONS

  --dry-run    Show what would be updated without making changes
  --verbose    Show detailed progress information
  --help       Show this help message

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Dancer2;
use Dancer2::Plugin::DBIC qw(schema);
use Getopt::Long;
use Pod::Usage;

my $dry_run = 0;
my $verbose = 0;
my $help = 0;

GetOptions(
    'dry-run'  => \$dry_run,
    'verbose'  => \$verbose,
    'help'     => \$help,
) or pod2usage(2);

pod2usage(1) if $help;

print "Backfilling previous_reading_value for meter readings...\n";
print "DRY RUN MODE - No changes will be made\n" if $dry_run;
print "\n";

# Get all meters
my @meters = schema->resultset('ElectricityMeter')->search(
    {},
    { order_by => 'id' }
)->all;

print "Found " . scalar(@meters) . " meters\n\n";

my $total_updated = 0;
my $total_unchanged = 0;
my $total_errors = 0;

foreach my $meter (@meters) {
    my $meter_id = $meter->id;
    my $meter_name = $meter->name;

    print "Processing meter: $meter_name (ID: $meter_id)\n" if $verbose;

    # Get all readings for this meter, ordered by period
    my @readings = schema->resultset('MeterReading')->search(
        { meter_id => $meter_id },
        {
            order_by => [
                { -asc => 'period_year' },
                { -asc => 'period_month' }
            ]
        }
    )->all;

    print "  Found " . scalar(@readings) . " readings\n" if $verbose;

    # Process each reading
    my $prev_reading;
    foreach my $reading (@readings) {
        my $period = sprintf("%04d-%02d", $reading->period_year, $reading->period_month);
        my $current_prev_value = $reading->previous_reading_value;
        my $expected_prev_value = $prev_reading ? $prev_reading->reading_value : undef;

        # Check if we need to update
        my $needs_update = 0;

        if (!defined $current_prev_value && defined $expected_prev_value) {
            # Need to set the previous value
            $needs_update = 1;
        } elsif (defined $current_prev_value && defined $expected_prev_value) {
            # Check if it's different
            if (abs($current_prev_value - $expected_prev_value) > 0.001) {
                $needs_update = 1;
                print "  WARNING: Reading $period has incorrect previous_reading_value\n";
                print "    Current: $current_prev_value, Expected: $expected_prev_value\n";
            }
        } elsif (defined $current_prev_value && !defined $expected_prev_value) {
            # First reading shouldn't have a previous value
            if ($current_prev_value != 0) {
                $needs_update = 1;
                print "  WARNING: First reading $period has previous_reading_value set\n";
            }
        }

        if ($needs_update) {
            if ($verbose) {
                printf("  Updating %s: reading_value=%.2f, previous=%.2f\n",
                    $period,
                    $reading->reading_value,
                    $expected_prev_value // 0
                );
            }

            unless ($dry_run) {
                eval {
                    # Recalculate consumption as well
                    my $new_consumption = $expected_prev_value
                        ? $reading->reading_value - $expected_prev_value
                        : 0;

                    $reading->update({
                        previous_reading_value => $expected_prev_value,
                        consumption => $new_consumption
                    });
                };
                if ($@) {
                    print "  ERROR updating reading $period: $@\n";
                    $total_errors++;
                    next;
                }
            }

            $total_updated++;
        } else {
            $total_unchanged++;
            print "  Reading $period is correct\n" if $verbose;
        }

        # Current reading becomes the previous for the next iteration
        $prev_reading = $reading;
    }

    print "\n" if $verbose;
}

print "\n";
print "=" x 60 . "\n";
print "Summary:\n";
print "  Total readings updated: $total_updated\n";
print "  Total readings unchanged: $total_unchanged\n";
print "  Total errors: $total_errors\n";

if ($dry_run) {
    print "\nDRY RUN: No changes were made to the database\n";
    print "Run without --dry-run to apply these changes\n";
} else {
    print "\nBackfill completed successfully!\n";
}

# Verification query suggestions
print "\n";
print "Recommended verification queries:\n";
print "  1. Check for inconsistent consumption values:\n";
print "     SELECT * FROM meter_readings\n";
print "     WHERE previous_reading_value IS NOT NULL\n";
print "     AND ABS(consumption - (reading_value - previous_reading_value)) > 0.01;\n";
print "\n";
print "  2. Check first readings per meter:\n";
print "     SELECT m.name, mr.*\n";
print "     FROM meter_readings mr\n";
print "     JOIN electricity_meters m ON m.id = mr.meter_id\n";
print "     WHERE previous_reading_value IS NULL\n";
print "     ORDER BY m.id, period_year, period_month;\n";
print "\n";

__END__

=head1 ALGORITHM

For each meter, the script:

1. Retrieves all readings ordered by period (year, month)
2. For each reading in chronological order:
   - If it's the first reading: previous_reading_value should be NULL
   - Otherwise: previous_reading_value should be the reading_value from the previous period
3. Compares the stored value with the expected value
4. Updates if necessary, along with recalculating consumption

=head1 AUTHOR

Property Management System

=cut
