package PropertyManager::Routes::Meters;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);

prefix '/api/meters';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my @meters = schema->resultset('ElectricityMeter')->search(
        { 'me.is_active' => 1 },
        { order_by => [{ -desc => 'me.is_general' }, { -asc => 'me.name' }], prefetch => 'tenant' }
    )->all;

    my @data = map {
        my %meter = $_->get_columns;
        $meter{tenant_name} = $_->tenant ? $_->tenant->name : undef;
        \%meter;
    } @meters;

    return { success => 1, data => \@data };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $meter = schema->resultset('ElectricityMeter')->find(route_parameters->get('id'));
    unless ($meter) {
        status 404;
        return { success => 0, error => 'Meter not found' };
    }
    return { success => 1, data => { meter => { $meter->get_columns } } };
};

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;
    unless ($data->{name}) {
        status 400;
        return { success => 0, error => 'name is required' };
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    my $meter = schema->resultset('ElectricityMeter')->create($data);
    return { success => 1, data => { meter => { $meter->get_columns } } };
};

put '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $meter = schema->resultset('ElectricityMeter')->find(route_parameters->get('id'));
    unless ($meter) {
        status 404;
        return { success => 0, error => 'Meter not found' };
    }

    my $data = request->data;
    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    $meter->update($data);
    return { success => 1, data => { meter => { $meter->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $meter = schema->resultset('ElectricityMeter')->find(route_parameters->get('id'));
    unless ($meter) {
        status 404;
        return { success => 0, error => 'Meter not found' };
    }

    if ($meter->is_general) {
        status 400;
        return { success => 0, error => 'Cannot delete General meter' };
    }

    my $readings_count = $meter->readings->count;
    if ($readings_count > 0) {
        status 400;
        return { success => 0, error => 'Cannot delete meter with readings' };
    }

    $meter->delete;
    return { success => 1, message => 'Meter deleted' };
};

1;
