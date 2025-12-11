package PropertyManager::Routes::Dashboard;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use PropertyManager::Services::Dashboard;

prefix '/api/dashboard';

my $dashboard_service;

hook 'before' => sub {
    $dashboard_service ||= PropertyManager::Services::Dashboard->new(schema => schema);
};

get '/summary' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $summary = $dashboard_service->get_summary();
    return { success => 1, data => $summary };
};

get '/charts/revenue' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $months = query_parameters->get('months') || 12;
    my $data = $dashboard_service->get_revenue_chart_data(months => $months);

    return { success => 1, data => $data };
};

get '/charts/utilities' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $year = query_parameters->get('year');
    my $month = query_parameters->get('month');

    my $data = $dashboard_service->get_utility_costs_chart_data(
        year => $year,
        month => $month,
    );

    return { success => 1, data => $data };
};

get '/charts/expenses-trend' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $months = query_parameters->get('months') || 6;
    my $data = $dashboard_service->get_expenses_trend_data(months => $months);

    return { success => 1, data => $data };
};

get '/charts/invoices-status' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $data = $dashboard_service->get_invoices_status_data();

    return { success => 1, data => $data };
};

get '/charts/cash-flow' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $months = query_parameters->get('months') || 12;
    my $data = $dashboard_service->get_cash_flow_chart_data(months => $months);

    return { success => 1, data => $data };
};

1;
