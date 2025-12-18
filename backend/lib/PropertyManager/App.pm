package PropertyManager::App;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use Try::Tiny;
use JSON::MaybeXS;

# ============================================================================
# ENVIRONMENT VARIABLE OVERRIDES FOR SECRETS
# ============================================================================
# Security secrets should ALWAYS be set via environment variables in production.
# Config file values are only used as development fallbacks.
# ============================================================================

# Override JWT secret from environment
if ($ENV{JWT_SECRET}) {
    config->{jwt}{secret_key} = $ENV{JWT_SECRET};
}

# Override CSRF secret from environment
if ($ENV{CSRF_SECRET}) {
    config->{csrf}{secret_key} = $ENV{CSRF_SECRET};
}

# Override session cookie key from environment
if ($ENV{SESSION_COOKIE_KEY}) {
    set session_cookie_key => $ENV{SESSION_COOKIE_KEY};
}

# Override Google OAuth credentials from environment
if ($ENV{GOOGLE_CLIENT_ID}) {
    config->{google}{client_id} = $ENV{GOOGLE_CLIENT_ID};
}
if ($ENV{GOOGLE_CLIENT_SECRET}) {
    config->{google}{client_secret} = $ENV{GOOGLE_CLIENT_SECRET};
}
if ($ENV{GOOGLE_REDIRECT_URI}) {
    config->{google}{redirect_uri} = $ENV{GOOGLE_REDIRECT_URI};
}

# Override frontend URL from environment
if ($ENV{FRONTEND_URL}) {
    config->{frontend_url} = $ENV{FRONTEND_URL};
}

# Override database credentials from environment (for backup service)
if ($ENV{DB_HOST}) {
    config->{database}{host} = $ENV{DB_HOST};
}
if ($ENV{DB_PORT}) {
    config->{database}{port} = $ENV{DB_PORT};
}
if ($ENV{DB_NAME}) {
    config->{database}{name} = $ENV{DB_NAME};
}
if ($ENV{DB_ROOT_PASSWORD}) {
    config->{database}{password} = $ENV{DB_ROOT_PASSWORD};
}

# Override DBIC plugin database connection from environment
# This is the main database connection used by the application
if ($ENV{DB_HOST} || $ENV{DB_PASSWORD} || $ENV{DB_USER} || $ENV{DB_NAME}) {
    my $host = $ENV{DB_HOST} || 'db';
    my $port = $ENV{DB_PORT} || 3306;
    my $name = $ENV{DB_NAME} || 'property_management';
    my $user = $ENV{DB_USER} || 'propman';
    my $pass = $ENV{DB_PASSWORD} || '';

    my $dsn = "dbi:MariaDB:database=$name;host=$host;port=$port";
    config->{plugins}{DBIC}{default}{dsn} = $dsn;
    config->{plugins}{DBIC}{default}{user} = $user;
    config->{plugins}{DBIC}{default}{password} = $pass;
}

# Rate limiting config from environment
if ($ENV{RATE_LIMIT_MAX_ATTEMPTS}) {
    config->{app}{max_login_attempts} = int($ENV{RATE_LIMIT_MAX_ATTEMPTS});
}
if ($ENV{RATE_LIMIT_WINDOW_SECONDS}) {
    config->{app}{lockout_duration} = int($ENV{RATE_LIMIT_WINDOW_SECONDS});
}

# Import all route modules
use PropertyManager::Routes::Auth;
use PropertyManager::Routes::Profile;
use PropertyManager::Routes::Company;
use PropertyManager::Routes::Tenants;
use PropertyManager::Routes::UtilityProviders;
use PropertyManager::Routes::ReceivedInvoices;
use PropertyManager::Routes::Meters;
use PropertyManager::Routes::MeterReadings;
use PropertyManager::Routes::UtilityCalculations;
use PropertyManager::Routes::Invoices;
use PropertyManager::Routes::Templates;
use PropertyManager::Routes::Dashboard;
use PropertyManager::Routes::Reports;
use PropertyManager::Routes::ExchangeRates;
use PropertyManager::Routes::Search;
use PropertyManager::Routes::Docs;
use PropertyManager::Routes::ActivityLogs;
use PropertyManager::Routes::Notifications;
use PropertyManager::Routes::GoogleDrive;

our $VERSION = '1.0.0';

# ============================================================================
# HOOKS - Execute before/after requests
# ============================================================================

# Add CORS headers to all responses
hook after => sub {
    my $response = shift;

    # Skip CORS for delayed responses (e.g., file downloads)
    return unless $response->can('header');

    my $cors_config = config->{cors};
    return unless $cors_config && $cors_config->{enabled};

    my $origin = request->header('Origin') || '';
    my $allowed_origins = $cors_config->{allowed_origins} || [];

    # Check if origin is allowed
    my $allow_origin = '';
    if (grep { $_ eq '*' } @$allowed_origins) {
        $allow_origin = '*';
    } elsif (grep { $_ eq $origin } @$allowed_origins) {
        $allow_origin = $origin;
    }

    if ($allow_origin) {
        $response->header('Access-Control-Allow-Origin' => $allow_origin);
        $response->header('Access-Control-Allow-Methods' =>
            join(', ', @{$cors_config->{allowed_methods}}));
        $response->header('Access-Control-Allow-Headers' =>
            join(', ', @{$cors_config->{allowed_headers}}));
        $response->header('Access-Control-Expose-Headers' =>
            join(', ', @{$cors_config->{expose_headers}})) if $cors_config->{expose_headers};
        $response->header('Access-Control-Allow-Credentials' => 'true')
            if $cors_config->{allow_credentials};
        $response->header('Access-Control-Max-Age' => $cors_config->{max_age})
            if $cors_config->{max_age};
    }
};

# Add security headers (production)
hook after => sub {
    my $response = shift;

    # Skip for delayed responses (e.g., file downloads)
    return unless $response->can('header');

    return unless setting('environment') eq 'production';

    my $security_headers = config->{app}{security_headers};
    return unless $security_headers;

    while (my ($header, $value) = each %$security_headers) {
        $response->header($header => $value);
    }
};

# Log requests in debug mode
hook before => sub {
    return unless config->{app}{debug_mode};

    my $method = request->method;
    my $path = request->path;
    debug("$method $path");
};

# CSRF Protection Hook - validates CSRF token for state-changing requests
hook before => sub {
    my $method = request->method;
    my $path = request->path;

    # Only check CSRF for state-changing methods
    return unless $method =~ /^(POST|PUT|DELETE|PATCH)$/i;

    # Skip CSRF validation for specific endpoints
    my @csrf_exempt = (
        '/api/auth/login',        # Login doesn't have CSRF token yet
        '/api/auth/logout',       # Logout is idempotent
        '/api/auth/csrf-refresh', # CSRF refresh uses only JWT auth
        '/api/google/callback',   # OAuth callback from Google
        '/health',                # Health check
        '/',                      # Root endpoint
    );

    return if grep { $path eq $_ } @csrf_exempt;

    # Skip if CSRF is disabled in config
    return unless config->{csrf}{enabled} // 1;  # Enabled by default

    # Only validate if there's an authenticated user (JWT was validated)
    # This is checked after require_auth() runs in the route handler
    # So we defer CSRF check to route handlers using require_csrf()
    # Global enforcement would require checking JWT here which is expensive

    # For now, routes that need CSRF protection should call require_csrf()
    # This hook logs potential CSRF issues for monitoring
    my $csrf_token = request->header('X-CSRF-Token');
    if (!$csrf_token && $method =~ /^(POST|PUT|DELETE|PATCH)$/i && $path =~ /^\/api\//) {
        debug("CSRF token missing for $method $path - route should call require_csrf()");
    }
};

# ============================================================================
# ROUTES - Application endpoints
# ============================================================================

# Root endpoint
get '/' => sub {
    return {
        success => 1,
        data => {
            application => 'PropertyManager',
            version => $VERSION,
            environment => setting('environment'),
        }
    };
};

# Health check endpoint
get '/health' => sub {
    my $db_ok = 0;

    try {
        my $schema = schema;
        my $result = $schema->resultset('User')->search({}, { rows => 1 })->count;
        $db_ok = 1;
    } catch {
        warning("Database health check failed: $_");
    };

    return {
        success => 1,
        data => {
            status => 'ok',
            database => $db_ok ? 'connected' : 'disconnected',
            timestamp => time(),
        }
    };
};

# Handle OPTIONS requests for CORS preflight
options qr{.*} => sub {
    status 200;
    return '';
};

# 404 handler - catches any unmatched routes
any qr{.*} => sub {
    status 'not_found';
    return {
        success => 0,
        error => 'Endpoint not found',
        path => request->path,
    };
};

1;

__END__

=head1 NAME

PropertyManager::App - Main Dancer2 application for Property Management System

=head1 SYNOPSIS

  use PropertyManager::App;

  # Start the application
  PropertyManager::App->to_app;

=head1 DESCRIPTION

This is the main application module for the PropertyManager system.
It loads all route modules and configures hooks for CORS, security headers,
and error handling.

=head1 ROUTES

The application provides the following route groups:

=over 4

=item * /api/auth - Authentication (login, logout, user info)

=item * /api/company - Company management

=item * /api/tenants - Tenant CRUD operations

=item * /api/utility-providers - Utility provider management

=item * /api/received-invoices - Received invoice tracking

=item * /api/meters - Electricity meter management

=item * /api/meter-readings - Meter reading entry

=item * /api/utility-calculations - Utility cost calculations

=item * /api/invoices - Invoice generation and management

=item * /api/templates - Invoice template management

=item * /api/dashboard - Dashboard metrics

=item * /api/reports - Report generation

=item * /api/exchange-rates - BNR exchange rates

=item * /api/search - Global search across tenants, invoices, and providers

=back

=head1 AUTHOR

Property Management System

=head1 LICENSE

Proprietary - All rights reserved

=cut
