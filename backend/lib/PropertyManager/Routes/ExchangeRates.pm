package PropertyManager::Routes::ExchangeRates;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth);
use PropertyManager::Services::BNRExchangeRate;

prefix '/api/exchange-rates';

my $bnr_service;

hook 'before' => sub {
    $bnr_service ||= PropertyManager::Services::BNRExchangeRate->new(
        schema => schema,
        config => config,
    );
};

get '/current' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $rate = $bnr_service->get_current_rate();

    unless ($rate) {
        status 500;
        return { success => 0, error => 'Failed to fetch exchange rate' };
    }

    return { success => 1, data => $rate };
};

get '/:date' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $date = route_parameters->get('date');

    # Use get_rate_for_invoice_date which implements the 1-day fallback logic
    my $rate = $bnr_service->get_rate_for_invoice_date($date);

    unless ($rate) {
        status 404;
        return {
            success => 0,
            error => 'Exchange rate not available for this date. Please enter manually.',
            code => 'RATE_NOT_AVAILABLE',
            requested_date => $date,
        };
    }

    return {
        success => 1,
        data => {
            exchange_rate => {
                rate => $rate->{rate},
                date => $rate->{date},
                source => $rate->{source},
                is_fallback => $rate->{fallback} ? 1 : 0,
            },
            requested_date => $date,
        }
    };
};

1;
