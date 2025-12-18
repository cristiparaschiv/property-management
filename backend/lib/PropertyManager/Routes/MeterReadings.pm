package PropertyManager::Routes::MeterReadings;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use Try::Tiny;

prefix '/api/meter-readings';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{meter_id} = query_parameters->get('meter_id') if query_parameters->get('meter_id');

    my @readings = schema->resultset('MeterReading')->search($search, {
        order_by => [{ -desc => 'period_year' }, { -desc => 'period_month' }],
        prefetch => 'meter',
    })->all;

    my @data = map {
        my %reading = $_->get_columns;
        $reading{meter_name} = $_->meter ? $_->meter->name : 'N/A';
        \%reading;
    } @readings;

    return { success => 1, data => \@data };
};

get '/period/:year/:month' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $year = route_parameters->get('year');
    my $month = route_parameters->get('month');

    my @readings = schema->resultset('MeterReading')->search(
        { period_year => $year, period_month => $month },
        { order_by => 'meter_id', prefetch => 'meter' }
    )->all;

    my @data = map {
        my %reading = $_->get_columns;
        $reading{meter_name} = $_->meter ? $_->meter->name : 'N/A';
        $reading{is_general} = $_->meter ? $_->meter->is_general : 0;
        \%reading;
    } @readings;

    return { success => 1, data => \@data };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $reading = schema->resultset('MeterReading')->find(route_parameters->get('id'));
    unless ($reading) {
        status 404;
        return { success => 0, error => 'Reading not found' };
    }
    return { success => 1, data => { reading => { $reading->get_columns } } };
};

post '/batch' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;
    my $readings = $data->{readings};

    unless ($readings && ref($readings) eq 'ARRAY' && @$readings) {
        status 400;
        return { success => 0, error => 'readings array is required' };
    }

    my @created = ();
    my @errors = ();

    try {
        schema->txn_do(sub {
            foreach my $reading_data (@$readings) {
                # Validate required fields
                unless ($reading_data->{meter_id} && $reading_data->{reading_date} &&
                        defined $reading_data->{reading_value} &&
                        $reading_data->{period_month} && $reading_data->{period_year}) {
                    push @errors, { meter_id => $reading_data->{meter_id}, error => 'Missing required fields' };
                    next;
                }

                # Validate reading value is not negative
                if ($reading_data->{reading_value} < 0) {
                    push @errors, { meter_id => $reading_data->{meter_id}, error => 'Reading value must be non-negative' };
                    next;
                }

                # Calculate consumption from previous reading
                my $prev_reading = _find_previous_reading(
                    schema => schema,
                    meter_id => $reading_data->{meter_id},
                    year => $reading_data->{period_year},
                    month => $reading_data->{period_month}
                );

                if ($prev_reading) {
                    my $prev_value = $prev_reading->reading_value;
                    $reading_data->{previous_reading_value} = $prev_value;
                    $reading_data->{consumption} = $reading_data->{reading_value} - $prev_value;
                } else {
                    $reading_data->{previous_reading_value} = undef;
                    $reading_data->{consumption} = 0;
                }

                # Remove id if passed
                delete $reading_data->{id};

                my $reading = schema->resultset('MeterReading')->update_or_create(
                    $reading_data,
                    { key => 'unique_meter_period' }
                );
                push @created, { $reading->get_columns };
            }
        });
    } catch {
        my $error = $_;
        error("Failed to create batch meter readings: $error");
        status 500;
        return { success => 0, error => 'Failed to create readings' };
    };

    return {
        success => 1,
        data => {
            created => \@created,
            errors => \@errors,
        }
    };
};

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;

    unless ($data->{meter_id} && $data->{reading_date} && defined $data->{reading_value} &&
            $data->{period_month} && $data->{period_year}) {
        status 400;
        return { success => 0, error => 'Missing required fields' };
    }

    # Validate reading value is not negative
    if ($data->{reading_value} < 0) {
        status 400;
        return { success => 0, error => 'Reading value must be non-negative' };
    }

    # Validate meter exists
    my $meter = schema->resultset('ElectricityMeter')->find($data->{meter_id});
    unless ($meter) {
        status 404;
        return { success => 0, error => 'Meter not found' };
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    # Calculate consumption from previous reading
    # Find previous period's reading for the same meter
    my $prev_reading = _find_previous_reading(
        schema => schema,
        meter_id => $data->{meter_id},
        year => $data->{period_year},
        month => $data->{period_month}
    );

    if ($prev_reading) {
        my $prev_value = $prev_reading->reading_value;
        my $consumption = $data->{reading_value} - $prev_value;

        # Validate consumption is not negative (possible meter replacement or error)
        if ($consumption < 0) {
            status 400;
            return {
                success => 0,
                error => 'Reading value is less than previous reading. If meter was replaced, please note this.',
                previous_reading => $prev_value,
                current_reading => $data->{reading_value},
            };
        }

        $data->{previous_reading_value} = $prev_value;
        $data->{consumption} = $consumption;
    } else {
        # First reading for this meter
        $data->{previous_reading_value} = undef;
        $data->{consumption} = 0;
    }

    my ($reading, $error);
    try {
        $reading = schema->resultset('MeterReading')->create($data);
    } catch {
        $error = $_;
        if ($error =~ /Duplicate entry/) {
            # Will be handled below
        } else {
            error("Failed to create meter reading: $error");
        }
    };

    if ($error) {
        if ($error =~ /Duplicate entry/) {
            status 409;
            return { success => 0, error => 'Reading already exists for this period' };
        }
        status 500;
        return { success => 0, error => 'Failed to create reading' };
    }

    return { success => 1, data => { reading => { $reading->get_columns } } };
};

put '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $reading = schema->resultset('MeterReading')->find(route_parameters->get('id'));
    unless ($reading) {
        status 404;
        return { success => 0, error => 'Reading not found' };
    }

    my $data = request->data;

    # Validate reading value is not negative
    if (exists $data->{reading_value} && $data->{reading_value} < 0) {
        status 400;
        return { success => 0, error => 'Reading value must be non-negative' };
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    # Recalculate consumption if reading_value changed
    if (exists $data->{reading_value}) {
        my $prev_reading = _find_previous_reading(
            schema => schema,
            meter_id => $reading->meter_id,
            year => $reading->period_year,
            month => $reading->period_month
        );

        if ($prev_reading) {
            my $prev_value = $prev_reading->reading_value;
            my $consumption = $data->{reading_value} - $prev_value;

            # Validate consumption is not negative
            if ($consumption < 0) {
                status 400;
                return {
                    success => 0,
                    error => 'Reading value is less than previous reading. If meter was replaced, please note this.',
                    previous_reading => $prev_value,
                    current_reading => $data->{reading_value},
                };
            }

            $data->{previous_reading_value} = $prev_value;
            $data->{consumption} = $consumption;
        } else {
            $data->{previous_reading_value} = undef;
            $data->{consumption} = 0;
        }
    }

    my $error;
    try {
        schema->txn_do(sub {
            $reading->update($data);

            # If reading_value was updated, recalculate consumption for subsequent readings
            if (exists $data->{reading_value}) {
                _recalculate_subsequent_readings(
                    schema => schema,
                    meter_id => $reading->meter_id,
                    year => $reading->period_year,
                    month => $reading->period_month
                );
            }
        });
    } catch {
        $error = $_;
        error("Failed to update meter reading: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to update reading' };
    }

    return { success => 1, data => { reading => { $reading->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $reading = schema->resultset('MeterReading')->find(route_parameters->get('id'));
    unless ($reading) {
        status 404;
        return { success => 0, error => 'Reading not found' };
    }

    my $meter_id = $reading->meter_id;
    my $year = $reading->period_year;
    my $month = $reading->period_month;

    my $error;
    try {
        schema->txn_do(sub {
            $reading->delete;

            # Recalculate consumption for subsequent readings
            _recalculate_subsequent_readings(
                schema => schema,
                meter_id => $meter_id,
                year => $year,
                month => $month
            );
        });
    } catch {
        $error = $_;
        error("Failed to delete meter reading: $error");
    };

    if ($error) {
        status 500;
        return { success => 0, error => 'Failed to delete reading' };
    }

    return { success => 1, message => 'Reading deleted' };
};

# Helper function to find the previous period's reading for a meter
sub _find_previous_reading {
    my %args = @_;
    my $schema = $args{schema};
    my $meter_id = $args{meter_id};
    my $year = $args{year};
    my $month = $args{month};

    # Calculate previous month/year
    my $prev_month = $month - 1;
    my $prev_year = $year;

    if ($prev_month < 1) {
        $prev_month = 12;
        $prev_year--;
    }

    # Try to find the immediate previous month first
    my $prev_reading = $schema->resultset('MeterReading')->search(
        {
            meter_id => $meter_id,
            period_year => $prev_year,
            period_month => $prev_month,
        }
    )->first;

    # If not found, find the most recent reading before this period
    unless ($prev_reading) {
        $prev_reading = $schema->resultset('MeterReading')->search(
            {
                meter_id => $meter_id,
                -or => [
                    { period_year => { '<' => $year } },
                    {
                        period_year => $year,
                        period_month => { '<' => $month }
                    }
                ]
            },
            {
                order_by => [
                    { -desc => 'period_year' },
                    { -desc => 'period_month' }
                ],
                rows => 1
            }
        )->first;
    }

    return $prev_reading;
}

# Helper function to find the next period's reading for a meter
sub _find_next_reading {
    my %args = @_;
    my $schema = $args{schema};
    my $meter_id = $args{meter_id};
    my $year = $args{year};
    my $month = $args{month};

    # Find the next reading chronologically
    my $next_reading = $schema->resultset('MeterReading')->search(
        {
            meter_id => $meter_id,
            -or => [
                { period_year => { '>' => $year } },
                {
                    period_year => $year,
                    period_month => { '>' => $month }
                }
            ]
        },
        {
            order_by => [
                { -asc => 'period_year' },
                { -asc => 'period_month' }
            ],
            rows => 1
        }
    )->first;

    return $next_reading;
}

# Helper function to recalculate consumption for all readings after a given period
sub _recalculate_subsequent_readings {
    my %args = @_;
    my $schema = $args{schema};
    my $meter_id = $args{meter_id};
    my $year = $args{year};
    my $month = $args{month};

    # Get all readings after this period, ordered chronologically
    my @subsequent_readings = $schema->resultset('MeterReading')->search(
        {
            meter_id => $meter_id,
            -or => [
                { period_year => { '>' => $year } },
                {
                    period_year => $year,
                    period_month => { '>' => $month }
                }
            ]
        },
        {
            order_by => [
                { -asc => 'period_year' },
                { -asc => 'period_month' }
            ]
        }
    )->all;

    # Recalculate consumption for each subsequent reading
    foreach my $next_reading (@subsequent_readings) {
        my $prev_reading = _find_previous_reading(
            schema => $schema,
            meter_id => $meter_id,
            year => $next_reading->period_year,
            month => $next_reading->period_month
        );

        if ($prev_reading) {
            my $prev_value = $prev_reading->reading_value;
            my $new_consumption = $next_reading->reading_value - $prev_value;

            $next_reading->update({
                previous_reading_value => $prev_value,
                consumption => $new_consumption
            });
        } else {
            $next_reading->update({
                previous_reading_value => undef,
                consumption => 0
            });
        }
    }
}

1;
