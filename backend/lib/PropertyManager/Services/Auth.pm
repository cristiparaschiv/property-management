package PropertyManager::Services::Auth;

use strict;
use warnings;
use Crypt::Bcrypt qw(bcrypt bcrypt_check);
use Crypt::JWT qw(encode_jwt decode_jwt);
use Digest::SHA qw(hmac_sha256_hex);
use MIME::Base64 qw(encode_base64url decode_base64url);
use Try::Tiny;
use DateTime;

=head1 NAME

PropertyManager::Services::Auth - Authentication service

=head1 SYNOPSIS

  use PropertyManager::Services::Auth;

  my $auth = PropertyManager::Services::Auth->new(schema => $schema, config => $config);

  # Authenticate user
  my $user = $auth->authenticate($username, $password);

  # Generate JWT token
  my $token = $auth->generate_token($user);

  # Validate JWT token
  my $user = $auth->validate_token($token);

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    die "config is required" unless $args{config};

    return bless \%args, $class;
}

=head2 authenticate

Authenticate user with username and password.
Returns user object if successful, undef otherwise.

=cut

sub authenticate {
    my ($self, $username, $password) = @_;

    return undef unless $username && $password;

    # Find user by username
    my $user = $self->{schema}->resultset('User')->find(
        { username => $username },
    );

    return undef unless $user;

    # Verify password
    my $valid = bcrypt_check($password, $user->password_hash);

    return undef unless $valid;

    # Update last login time
    $user->update({ last_login => DateTime->now });

    return $user;
}

=head2 generate_token

Generate JWT token for authenticated user.
Returns JWT token string.

=cut

sub generate_token {
    my ($self, $user) = @_;

    return undef unless $user;

    my $jwt_config = $self->{config}{jwt} || {};
    my $secret = $jwt_config->{secret_key} || die "JWT secret_key not configured";
    my $algorithm = $jwt_config->{algorithm} || 'HS256';
    my $expiration = $jwt_config->{expiration} || 86400; # 24 hours default

    my $now = time();

    my $payload = {
        sub => $user->id,
        username => $user->username,
        email => $user->email,
        iat => $now,
        exp => $now + $expiration,
    };

    my $token = encode_jwt(
        payload => $payload,
        key => $secret,
        alg => $algorithm,
    );

    return $token;
}

=head2 validate_token

Validate JWT token and return user object.
Returns user object if valid, undef otherwise.

=cut

sub validate_token {
    my ($self, $token) = @_;

    return undef unless $token;

    my $jwt_config = $self->{config}{jwt} || {};
    my $secret = $jwt_config->{secret_key} || die "JWT secret_key not configured";
    my $algorithm = $jwt_config->{algorithm} || 'HS256';

    my $payload;
    try {
        $payload = decode_jwt(
            token => $token,
            key => $secret,
            alg => $algorithm,
        );
    } catch {
        warn "JWT validation failed: $_";
        return undef;
    };

    return undef unless $payload && $payload->{sub};

    # Check expiration
    if ($payload->{exp} && $payload->{exp} < time()) {
        return undef;
    }

    # Load user from database
    my $user = $self->{schema}->resultset('User')->find($payload->{sub});

    return $user;
}

=head2 hash_password

Hash password using bcrypt.
Returns bcrypt hash string.

=cut

sub hash_password {
    my ($self, $password) = @_;

    return undef unless $password;

    my $cost = $self->{config}{app}{bcrypt_cost} || 12;

    # Generate random 16-byte salt
    my $salt = '';
    $salt .= chr(int(rand(256))) for 1..16;

    my $hash = bcrypt($password, '2b', $cost, $salt);

    return $hash;
}

=head2 extract_token

Extract JWT token from Authorization header or cookie.
Returns token string or undef.

=cut

sub extract_token {
    my ($self, $request) = @_;

    # Try Authorization header first (Bearer token)
    my $auth_header = $request->header('Authorization');
    if ($auth_header && $auth_header =~ /^Bearer\s+(.+)$/i) {
        return $1;
    }

    # Try cookie as fallback (only for Dancer2 requests)
    if ($request->can('cookies')) {
        my $cookies = $request->cookies;
        if ($cookies && ref($cookies) eq 'HASH' && $cookies->{auth_token}) {
            return $cookies->{auth_token};
        }
    }

    return undef;
}

=head2 generate_csrf_token

Generate a CSRF token for the authenticated user.
The token contains user_id, timestamp, and is signed with HMAC-SHA256.
Token format: base64url(user_id:timestamp):signature

=cut

sub generate_csrf_token {
    my ($self, $user_id) = @_;

    return undef unless $user_id;

    my $csrf_secret = $self->{config}{csrf}{secret_key}
        || $self->{config}{jwt}{secret_key}  # Fallback to JWT secret
        || die "CSRF secret not configured";

    my $timestamp = time();
    my $expiration = $self->{config}{csrf}{expiration} || 3600;  # 1 hour default

    # Create payload: user_id:timestamp:expiration
    my $payload = "$user_id:$timestamp:$expiration";
    my $encoded_payload = encode_base64url($payload);

    # Generate signature
    my $signature = hmac_sha256_hex($encoded_payload, $csrf_secret);

    # Return token: payload.signature
    return "$encoded_payload.$signature";
}

=head2 validate_csrf_token

Validate a CSRF token for the given user.
Returns 1 if valid, 0 otherwise.

=cut

sub validate_csrf_token {
    my ($self, $token, $user_id) = @_;

    return 0 unless $token && $user_id;

    my $csrf_secret = $self->{config}{csrf}{secret_key}
        || $self->{config}{jwt}{secret_key}  # Fallback to JWT secret
        || die "CSRF secret not configured";

    # Split token into payload and signature
    my ($encoded_payload, $signature) = split(/\./, $token, 2);
    return 0 unless $encoded_payload && $signature;

    # Verify signature
    my $expected_signature = hmac_sha256_hex($encoded_payload, $csrf_secret);
    return 0 unless $signature eq $expected_signature;

    # Decode and parse payload
    my $payload;
    try {
        $payload = decode_base64url($encoded_payload);
    } catch {
        return 0;
    };
    return 0 unless $payload;

    my ($token_user_id, $timestamp, $expiration) = split(/:/, $payload, 3);
    return 0 unless $token_user_id && $timestamp && $expiration;

    # Verify user_id matches
    return 0 unless $token_user_id == $user_id;

    # Verify not expired
    my $current_time = time();
    return 0 if ($current_time - $timestamp) > $expiration;

    return 1;
}

1;

__END__

=head1 DESCRIPTION

This service handles all authentication operations including:
- Password hashing with bcrypt
- User authentication
- JWT token generation
- JWT token validation
- Token extraction from requests

=head1 SECURITY

- Passwords are hashed using bcrypt with configurable cost factor
- JWT tokens have configurable expiration time
- Tokens are signed with HS256 (configurable)
- Last login time is tracked for audit purposes

=head1 AUTHOR

Property Management System

=cut
