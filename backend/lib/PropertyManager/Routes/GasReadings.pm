package PropertyManager::Routes::GasReadings;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use Try::Tiny;

prefix '/api/gas-readings';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{tenant_id} = query_parameters->get('tenant_id') if query_parameters->get('tenant_id');
    $search->{period_year} = query_parameters->get('year') if query_parameters->get('year');
    $search->{period_month} = query_parameters->get('month') if query_parameters->get('month');

    my @rows = schema->resultset('GasReading')->search($search, {
        order_by => [{ -desc => 'period_year' }, { -desc => 'period_month' }, 'tenant_id'],
        prefetch => 'tenant',
    })->all;

    my @data = map {
        my %r = $_->get_columns;
        $r{tenant_name} = $_->tenant ? $_->tenant->name : 'N/A';
        \%r;
    } @rows;

    return { success => 1, data => \@data };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $row = schema->resultset('GasReading')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Reading not found' }; }
    return { success => 1, data => { reading => { $row->get_columns } } };
};

post '' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $d = request->data;
    for my $f (qw(tenant_id reading_date reading_value period_month period_year)) {
        unless (defined $d->{$f}) { status 400; return { success => 0, error => "$f is required" }; }
    }
    if ($d->{reading_value} < 0) {
        status 400; return { success => 0, error => 'reading_value must be non-negative' };
    }

    my $created;
    try {
        # compute previous + consumption from last reading
        my $prev = schema->resultset('GasReading')->search(
            { tenant_id => $d->{tenant_id} },
            { order_by => [{ -desc => 'period_year' }, { -desc => 'period_month' }], rows => 1 }
        )->first;

        my $prev_value = $prev ? $prev->reading_value : undef;
        my $consumption = defined $prev_value ? ($d->{reading_value} - $prev_value) : undef;

        $created = schema->resultset('GasReading')->create({
            tenant_id => $d->{tenant_id},
            reading_date => $d->{reading_date},
            reading_value => $d->{reading_value},
            previous_reading_value => $prev_value,
            consumption => $consumption,
            period_month => $d->{period_month},
            period_year  => $d->{period_year},
            notes => $d->{notes},
        });
    } catch {
        status 500; return { success => 0, error => "Create failed: $_" };
    };

    return { success => 1, data => { reading => { $created->get_columns } } };
};

put '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('GasReading')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Reading not found' }; }

    my $d = request->data;
    try {
        $row->update({
            map { $_ => $d->{$_} } grep { exists $d->{$_} }
            qw(reading_date reading_value period_month period_year notes)
        });
        if (exists $d->{reading_value} && defined $row->previous_reading_value) {
            $row->update({ consumption => $row->reading_value - $row->previous_reading_value });
        }
    } catch {
        status 500; return { success => 0, error => "Update failed: $_" };
    };

    return { success => 1, data => { reading => { $row->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('GasReading')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Reading not found' }; }
    $row->delete;
    return { success => 1 };
};

1;
