package PropertyManager::Routes::MeteredCalculationInputs;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use Try::Tiny;

prefix '/api/metered-inputs';

get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $search = {};
    $search->{calculation_id} = query_parameters->get('calculation_id')
        if query_parameters->get('calculation_id');
    $search->{utility_type} = query_parameters->get('utility_type')
        if query_parameters->get('utility_type');

    my @rows = schema->resultset('MeteredCalculationInput')->search($search)->all;
    return { success => 1, data => [ map { +{ $_->get_columns } } @rows ] };
};

post '' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $d = request->data;
    for my $f (qw(calculation_id received_invoice_id utility_type total_units)) {
        unless (defined $d->{$f}) { status 400; return { success => 0, error => "$f is required" }; }
    }

    unless ($d->{utility_type} eq 'gas' or $d->{utility_type} eq 'water') {
        status 400;
        return { success => 0, error => "utility_type must be 'gas' or 'water'" };
    }

    if ($d->{utility_type} eq 'water') {
        unless (defined $d->{consumption_amount} && defined $d->{rain_amount}) {
            status 400;
            return { success => 0, error => "consumption_amount and rain_amount are required for water" };
        }
    }

    my $row;
    try {
        $row = schema->resultset('MeteredCalculationInput')->update_or_create(
            {
                calculation_id => $d->{calculation_id},
                utility_type   => $d->{utility_type},
                received_invoice_id => $d->{received_invoice_id},
                total_units    => $d->{total_units},
                consumption_amount => $d->{consumption_amount},
                rain_amount    => $d->{rain_amount},
                notes          => $d->{notes},
            },
            { key => 'calc_utility_unique' }
        );
    } catch {
        status 500; return { success => 0, error => "Save failed: $_" };
    };

    return { success => 1, data => { input => { $row->get_columns } } };
};

del '/:id' => sub {
    my $auth_error = require_auth(); return $auth_error if $auth_error;
    my $csrf_error = require_csrf(); return $csrf_error if $csrf_error;

    my $row = schema->resultset('MeteredCalculationInput')->find(route_parameters->get('id'));
    unless ($row) { status 404; return { success => 0, error => 'Input not found' }; }
    $row->delete;
    return { success => 1 };
};

1;
