package PropertyManager::Routes::Auth;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Services::Auth;
use PropertyManager::Services::RateLimiter;
use Try::Tiny;

use Exporter 'import';
our @EXPORT_OK = qw(require_auth require_csrf get_current_user);

=head2 get_current_user

Returns the current authenticated user from request var.
Must be called after require_auth().

=cut

sub get_current_user {
    return var('user') ? { var('user')->get_columns } : undef;
}

# Initialize services
my ($auth_service, $rate_limiter);

hook 'before' => sub {
    $auth_service ||= PropertyManager::Services::Auth->new(
        schema => schema,
        config => config,
    );
    $rate_limiter ||= PropertyManager::Services::RateLimiter->new(
        schema => schema,
        config => config,
    );
};

# ============================================================================
# Authentication Middleware
# ============================================================================

=head2 require_auth

Middleware to protect routes requiring authentication.
Call this in protected routes to ensure user is authenticated.

=cut

sub require_auth {
    my $token = $auth_service->extract_token(request);

    unless ($token) {
        status 401;
        return {
            success => 0,
            error => 'Authentication required',
            code => 'AUTH_REQUIRED',
        };
    }

    my $user = $auth_service->validate_token($token);

    unless ($user) {
        status 401;
        return {
            success => 0,
            error => 'Invalid or expired token',
            code => 'AUTH_INVALID',
        };
    }

    # Store user in request var for use in route handlers
    var user => $user;

    return undef;  # No error, authentication successful
}

=head2 require_csrf

Middleware to validate CSRF token for state-changing operations.
Must be called AFTER require_auth since it needs the authenticated user.
Only validates for POST, PUT, DELETE, PATCH methods.

=cut

sub require_csrf {
    my $method = request->method;

    # Only check CSRF for state-changing methods
    return undef unless $method =~ /^(POST|PUT|DELETE|PATCH)$/i;

    my $user = var('user');
    unless ($user) {
        status 401;
        return {
            success => 0,
            error => 'Authentication required before CSRF validation',
            code => 'AUTH_REQUIRED',
        };
    }

    my $csrf_token = request->header('X-CSRF-Token');

    unless ($csrf_token) {
        status 403;
        return {
            success => 0,
            error => 'CSRF token is required',
            code => 'CSRF_MISSING',
        };
    }

    my $valid = $auth_service->validate_csrf_token($csrf_token, $user->id);

    unless ($valid) {
        status 403;
        return {
            success => 0,
            error => 'Invalid or expired CSRF token',
            code => 'CSRF_INVALID',
        };
    }

    return undef;  # CSRF validation successful
}

# ============================================================================
# Auth Routes
# ============================================================================

=head2 POST /api/auth/login

User login endpoint.
Accepts: { username, password }
Returns: { success, data: { token, user } }

=cut

post '/api/auth/login' => sub {
    my $data = request->data;
    my $client_ip = request->address;

    # Check rate limiting before processing login
    my $lockout_info = $rate_limiter->get_lockout_info($client_ip);
    if ($lockout_info->{is_locked}) {
        status 429;
        return {
            success => 0,
            error => 'Prea multe încercări de autentificare. Încercați din nou mai târziu.',
            code => 'RATE_LIMITED',
            retry_after => $lockout_info->{lockout_remaining},
        };
    }

    unless ($data->{username} && $data->{password}) {
        status 400;
        return {
            success => 0,
            error => 'Username and password are required',
            code => 'MISSING_CREDENTIALS',
        };
    }

    my $user;
    try {
        $user = $auth_service->authenticate($data->{username}, $data->{password});
    } catch {
        error("Authentication error: $_");
        status 500;
        return {
            success => 0,
            error => 'Authentication service error',
            code => 'AUTH_ERROR',
        };
    };

    unless ($user) {
        # Record failed login attempt for rate limiting
        $rate_limiter->record_failed_attempt($client_ip, $data->{username});

        # Get updated lockout info to include in response
        my $updated_info = $rate_limiter->get_lockout_info($client_ip);
        my $remaining_attempts = $updated_info->{max_attempts} - $updated_info->{attempts};

        status 401;
        return {
            success => 0,
            error => 'Invalid username or password',
            code => 'INVALID_CREDENTIALS',
            remaining_attempts => $remaining_attempts > 0 ? $remaining_attempts : 0,
        };
    }

    # Successful login - clear failed attempts and record success
    $rate_limiter->clear_attempts($client_ip);
    $rate_limiter->record_successful_attempt($client_ip, $data->{username});

    my $token = $auth_service->generate_token($user);
    my $csrf_token = $auth_service->generate_csrf_token($user->id);

    # Get JWT expiration from config (default 24 hours)
    my $jwt_expiration = config->{jwt}{expiration} || 86400;

    # Set JWT in HttpOnly cookie for security
    cookie auth_token => $token, (
        expires   => time + $jwt_expiration,
        http_only => 1,
        secure    => (config->{environment} || '') eq 'production' ? 1 : 0,
        same_site => 'Strict',
        path      => '/',
    );

    return {
        success => 1,
        data => {
            csrf_token => $csrf_token,
            user => $user->TO_JSON,
        },
    };
};

=head2 POST /api/auth/logout

User logout endpoint.
Invalidates the current session.

=cut

post '/api/auth/logout' => sub {
    # Clear the auth cookie by setting it to empty with past expiration
    cookie auth_token => '', (
        expires   => 1,  # Expire immediately (epoch + 1 second)
        http_only => 1,
        secure    => (config->{environment} || '') eq 'production' ? 1 : 0,
        same_site => 'Strict',
        path      => '/',
    );

    return {
        success => 1,
        message => 'Logged out successfully',
    };
};

=head2 GET /api/auth/me

Get current authenticated user information.
Protected route - requires valid token.

=cut

get '/api/auth/me' => sub {
    # Require authentication
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = var('user');

    # Generate fresh CSRF token
    my $csrf_token = $auth_service->generate_csrf_token($user->id);

    return {
        success => 1,
        data => {
            user => $user->TO_JSON,
            csrf_token => $csrf_token,
        },
    };
};

=head2 POST /api/auth/csrf-refresh

Refresh CSRF token for authenticated user.
Protected route - requires valid JWT token.

=cut

post '/api/auth/csrf-refresh' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = var('user');
    my $csrf_token = $auth_service->generate_csrf_token($user->id);

    return {
        success => 1,
        data => {
            csrf_token => $csrf_token,
        },
    };
};

=head2 POST /api/auth/change-password

Change password for authenticated user.
Protected route - requires valid JWT token and CSRF token.

Request body:
  {
    "current_password": "string",
    "new_password": "string"
  }

Password requirements:
  - Minimum 8 characters
  - Must contain at least one uppercase letter
  - Must contain at least one lowercase letter
  - Must contain at least one digit
  - Must be different from current password

=cut

post '/api/auth/change-password' => sub {
    # Require authentication
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    # Require CSRF token for this state-changing operation
    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = var('user');
    my $data = request->data;

    # Validate required fields
    unless ($data->{current_password} && $data->{new_password}) {
        status 400;
        return {
            success => 0,
            error => 'Current password and new password are required',
            code => 'MISSING_FIELDS',
        };
    }

    # Validate new password format and complexity
    my $password_error = _validate_password($data->{new_password});
    if ($password_error) {
        status 400;
        return {
            success => 0,
            error => $password_error,
            code => 'INVALID_PASSWORD',
        };
    }

    # Check that new password is different from current password
    # Use constant-time comparison to prevent timing attacks
    my $same_password = try {
        require Crypt::Bcrypt;
        Crypt::Bcrypt::bcrypt_check($data->{new_password}, $user->password_hash);
    } catch {
        error("Error checking password similarity: $_");
        return 0;
    };

    if ($same_password) {
        status 400;
        return {
            success => 0,
            error => 'New password must be different from current password',
            code => 'SAME_PASSWORD',
        };
    }

    # Verify current password
    my $verified = try {
        require Crypt::Bcrypt;
        Crypt::Bcrypt::bcrypt_check($data->{current_password}, $user->password_hash);
    } catch {
        error("Error verifying current password: $_");
        return 0;
    };

    unless ($verified) {
        status 401;
        return {
            success => 0,
            error => 'Current password is incorrect',
            code => 'INVALID_CURRENT_PASSWORD',
        };
    }

    # Hash new password
    my $new_hash;
    try {
        $new_hash = $auth_service->hash_password($data->{new_password});
    } catch {
        error("Error hashing new password: $_");
        status 500;
        return {
            success => 0,
            error => 'Failed to process password change',
            code => 'HASH_ERROR',
        };
    };

    unless ($new_hash) {
        status 500;
        return {
            success => 0,
            error => 'Failed to process password change',
            code => 'HASH_ERROR',
        };
    }

    # Update user password in database
    try {
        $user->update({ password_hash => $new_hash });
    } catch {
        error("Error updating password in database: $_");
        status 500;
        return {
            success => 0,
            error => 'Failed to update password',
            code => 'UPDATE_ERROR',
        };
    };

    return {
        success => 1,
        message => 'Password changed successfully',
    };
};

=head2 _validate_password

Internal helper to validate password complexity requirements.
Returns error message if invalid, undef if valid.

=cut

sub _validate_password {
    my ($password) = @_;

    return "Password is required" unless defined $password;

    # Minimum length check
    return "Password must be at least 8 characters long"
        if length($password) < 8;

    # Check for at least one uppercase letter
    return "Password must contain at least one uppercase letter"
        unless $password =~ /[A-Z]/;

    # Check for at least one lowercase letter
    return "Password must contain at least one lowercase letter"
        unless $password =~ /[a-z]/;

    # Check for at least one digit
    return "Password must contain at least one digit"
        unless $password =~ /[0-9]/;

    # Optional: Check for maximum length (prevent DoS via bcrypt with very long passwords)
    return "Password must not exceed 72 characters"
        if length($password) > 72;

    return undef;  # Password is valid
}

1;

__END__

=head1 NAME

PropertyManager::Routes::Auth - Authentication routes

=head1 ROUTES

=over 4

=item POST /api/auth/login - User login

=item POST /api/auth/logout - User logout

=item GET /api/auth/me - Get current user

=item POST /api/auth/change-password - Change password

=back

=head1 AUTHENTICATION

All routes except /api/auth/login should call require_auth() to ensure
the user is authenticated. The authenticated user is stored in var('user')
for use in route handlers.

=cut
