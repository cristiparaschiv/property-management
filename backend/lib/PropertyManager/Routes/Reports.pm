package PropertyManager::Routes::Reports;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use PropertyManager::Services::Reports;

prefix '/api/reports';

my $reports_service;

hook 'before' => sub {
    $reports_service ||= PropertyManager::Services::Reports->new(schema => schema);
};

get '/invoices' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my %filters;
    $filters{start_date} = query_parameters->get('start_date') if query_parameters->get('start_date');
    $filters{end_date} = query_parameters->get('end_date') if query_parameters->get('end_date');
    $filters{tenant_id} = query_parameters->get('tenant_id') if query_parameters->get('tenant_id');
    $filters{invoice_type} = query_parameters->get('type') if query_parameters->get('type');
    $filters{is_paid} = query_parameters->get('paid') ? 1 : 0 if defined query_parameters->get('paid');

    my $report = $reports_service->invoices_report(%filters);
    return { success => 1, data => $report };
};

get '/payments' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my %filters;
    $filters{start_date} = query_parameters->get('start_date') if query_parameters->get('start_date');
    $filters{end_date} = query_parameters->get('end_date') if query_parameters->get('end_date');

    my $report = $reports_service->payments_report(%filters);
    return { success => 1, data => $report };
};

get '/tenant/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $tenant_id = route_parameters->get('id');

    my %filters;
    $filters{start_date} = query_parameters->get('start_date') if query_parameters->get('start_date');
    $filters{end_date} = query_parameters->get('end_date') if query_parameters->get('end_date');

    my $report = $reports_service->tenant_report($tenant_id, %filters);
    return { success => 1, data => $report };
};

1;
