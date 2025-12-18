package PropertyManager::Routes::UtilityProviders;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);

prefix '/api/utility-providers';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{type} = query_parameters->get('type') if query_parameters->get('type');
    $search->{is_active} = query_parameters->get('active') ? 1 : 0 if defined query_parameters->get('active');

    my @providers = schema->resultset('UtilityProvider')->search($search, { order_by => 'name' })->all;
    return { success => 1, data => [ map { { $_->get_columns } } @providers ] };
};

get '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $provider = schema->resultset('UtilityProvider')->find(route_parameters->get('id'));
    unless ($provider) {
        status 404;
        return { success => 0, error => 'Provider not found' };
    }
    return { success => 1, data => { provider => { $provider->get_columns } } };
};

post '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $data = request->data;
    unless ($data->{name} && $data->{type}) {
        status 400;
        return { success => 0, error => 'name and type are required' };
    }

    # Validate type is a valid enum value
    my @valid_types = qw(electricity gas water salubrity internet other);
    unless (grep { $_ eq $data->{type} } @valid_types) {
        status 400;
        return { success => 0, error => 'Invalid type. Must be one of: ' . join(', ', @valid_types) };
    }

    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    my $provider = schema->resultset('UtilityProvider')->create($data);
    return { success => 1, data => { provider => { $provider->get_columns } } };
};

put '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $provider = schema->resultset('UtilityProvider')->find(route_parameters->get('id'));
    unless ($provider) {
        status 404;
        return { success => 0, error => 'Provider not found' };
    }

    my $data = request->data;
    # Remove id if passed (parameter tampering prevention)
    delete $data->{id};

    $provider->update($data);
    return { success => 1, data => { provider => { $provider->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $provider = schema->resultset('UtilityProvider')->find(route_parameters->get('id'));
    unless ($provider) {
        status 404;
        return { success => 0, error => 'Provider not found' };
    }

    $provider->update({ is_active => 0 });
    return { success => 1, message => 'Provider deactivated' };
};

1;
