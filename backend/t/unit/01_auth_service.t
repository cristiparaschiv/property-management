#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::Auth;
use Crypt::Bcrypt qw(bcrypt_check);

# Get database schema
my $schema = TestHelper::schema();

# Create auth service instance
my $config = {
    jwt => {
        secret_key => 'test_secret_key_12345',
        algorithm => 'HS256',
        expiration => 3600,  # 1 hour for testing
    },
    app => {
        bcrypt_cost => 8,  # Lower cost for faster tests
    },
};

my $auth = PropertyManager::Services::Auth->new(
    schema => $schema,
    config => $config,
);

# Test plan
plan tests => 21;

# ============================================================================
# Test: new() constructor
# ============================================================================

subtest 'Constructor requires schema and config' => sub {
    plan tests => 3;

    eval {
        PropertyManager::Services::Auth->new();
    };
    like($@, qr/schema is required/, 'Dies without schema');

    eval {
        PropertyManager::Services::Auth->new(schema => $schema);
    };
    like($@, qr/config is required/, 'Dies without config');

    my $service = PropertyManager::Services::Auth->new(
        schema => $schema,
        config => $config,
    );
    isa_ok($service, 'PropertyManager::Services::Auth', 'Creates instance with required params');
};

# ============================================================================
# Test: hash_password()
# ============================================================================

subtest 'hash_password() generates bcrypt hash' => sub {
    plan tests => 4;

    my $password = 'test_password_123';
    my $hash = $auth->hash_password($password);

    ok($hash, 'Returns hash');
    like($hash, qr/^\$2b\$/, 'Hash starts with $2b$ (bcrypt identifier)');
    ok(bcrypt_check($password, $hash), 'Generated hash validates correctly');

    # Test with empty password
    my $empty_hash = $auth->hash_password('');
    ok(!defined $empty_hash, 'Returns undef for empty password');
};

# ============================================================================
# Test: authenticate()
# ============================================================================

subtest 'authenticate() validates user credentials' => sub {
    plan tests => 6;

    # Get the admin user
    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    ok($admin, 'Admin user exists in database');

    # Test successful authentication
    my $user = $auth->authenticate('admin', 'changeme');
    ok($user, 'Authentication succeeds with correct credentials');
    is($user->username, 'admin', 'Returns correct user object');

    # Test failed authentication - wrong password
    my $fail1 = $auth->authenticate('admin', 'wrong_password');
    ok(!defined $fail1, 'Authentication fails with wrong password');

    # Test failed authentication - non-existent user
    my $fail2 = $auth->authenticate('nonexistent', 'password');
    ok(!defined $fail2, 'Authentication fails for non-existent user');

    # Test with empty credentials
    my $fail3 = $auth->authenticate('', '');
    ok(!defined $fail3, 'Authentication fails with empty credentials');
};

# ============================================================================
# Test: generate_token()
# ============================================================================

subtest 'generate_token() creates JWT token' => sub {
    plan tests => 5;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });

    my $token = $auth->generate_token($admin);
    ok($token, 'Returns token');
    like($token, qr/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/, 'Token has JWT format (3 parts)');

    # Test with undef user
    my $no_token = $auth->generate_token(undef);
    ok(!defined $no_token, 'Returns undef for undef user');

    # Verify token contains expected payload by decoding
    use Crypt::JWT qw(decode_jwt);
    my $payload = decode_jwt(
        token => $token,
        key => $config->{jwt}{secret_key},
    );

    ok($payload, 'Token can be decoded');
    is($payload->{username}, 'admin', 'Token contains username');
};

# ============================================================================
# Test: validate_token()
# ============================================================================

subtest 'validate_token() verifies JWT tokens' => sub {
    plan tests => 7;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $token = $auth->generate_token($admin);

    # Test valid token
    my $user = $auth->validate_token($token);
    ok($user, 'Valid token returns user');
    is($user->username, 'admin', 'Returns correct user');

    # Test invalid token
    my $invalid = $auth->validate_token('invalid.token.here');
    ok(!defined $invalid, 'Invalid token returns undef');

    # Test empty token
    my $empty = $auth->validate_token('');
    ok(!defined $empty, 'Empty token returns undef');

    # Test undef token
    my $undef_tok = $auth->validate_token(undef);
    ok(!defined $undef_tok, 'Undef token returns undef');

    # Test expired token
    use Crypt::JWT qw(encode_jwt);
    my $expired_token = encode_jwt(
        payload => {
            sub => $admin->id,
            username => $admin->username,
            email => $admin->email,
            iat => time() - 7200,
            exp => time() - 3600,  # Expired 1 hour ago
        },
        key => $config->{jwt}{secret_key},
        alg => 'HS256',
    );

    my $expired_user = $auth->validate_token($expired_token);
    ok(!defined $expired_user, 'Expired token returns undef');

    # Test token with non-existent user ID
    my $bad_user_token = encode_jwt(
        payload => {
            sub => 99999,  # Non-existent user ID
            username => 'fake',
            iat => time(),
            exp => time() + 3600,
        },
        key => $config->{jwt}{secret_key},
        alg => 'HS256',
    );

    my $bad_user = $auth->validate_token($bad_user_token);
    ok(!defined $bad_user, 'Token with non-existent user ID returns undef');
};

# ============================================================================
# Test: extract_token()
# ============================================================================

subtest 'extract_token() extracts token from request' => sub {
    plan tests => 4;

    # Mock HTTP::Request object
    use HTTP::Request;

    # Test Bearer token in Authorization header
    my $req1 = HTTP::Request->new(GET => '/api/test');
    $req1->header(Authorization => 'Bearer my_test_token_123');

    my $token1 = $auth->extract_token($req1);
    is($token1, 'my_test_token_123', 'Extracts Bearer token from Authorization header');

    # Test case-insensitive Bearer
    my $req2 = HTTP::Request->new(GET => '/api/test');
    $req2->header(Authorization => 'bearer another_token_456');

    my $token2 = $auth->extract_token($req2);
    is($token2, 'another_token_456', 'Extracts bearer token (case insensitive)');

    # Test no Authorization header
    my $req3 = HTTP::Request->new(GET => '/api/test');

    my $token3 = $auth->extract_token($req3);
    ok(!defined $token3, 'Returns undef when no Authorization header');

    # Test malformed Authorization header
    my $req4 = HTTP::Request->new(GET => '/api/test');
    $req4->header(Authorization => 'InvalidFormat');

    my $token4 = $auth->extract_token($req4);
    ok(!defined $token4, 'Returns undef for malformed Authorization header');
};

# ============================================================================
# Test: Integration - Full authentication flow
# ============================================================================

subtest 'Full authentication flow' => sub {
    plan tests => 5;

    # Step 1: Authenticate user
    my $user = $auth->authenticate('admin', 'changeme');
    ok($user, 'Step 1: User authenticated');

    # Step 2: Generate token
    my $token = $auth->generate_token($user);
    ok($token, 'Step 2: Token generated');

    # Step 3: Validate token
    my $validated_user = $auth->validate_token($token);
    ok($validated_user, 'Step 3: Token validated');
    is($validated_user->id, $user->id, 'Validated user matches original');

    # Step 4: Verify last_login was updated
    $user->discard_changes;  # Reload from database
    ok($user->last_login, 'Last login timestamp was updated');
};

# ============================================================================
# Test: Password hashing with different costs
# ============================================================================

subtest 'Password hashing respects bcrypt cost' => sub {
    plan tests => 2;

    my $password = 'test123';
    my $hash = $auth->hash_password($password);

    # Extract cost from hash (bcrypt format: $2b$XX$...)
    $hash =~ /^\$2b\$(\d+)\$/;
    my $cost = $1;

    is($cost, '08', 'Uses configured bcrypt cost');
    ok(bcrypt_check($password, $hash), 'Hash with custom cost validates correctly');
};

# ============================================================================
# Test: Token payload contents
# ============================================================================

subtest 'Token payload contains required fields' => sub {
    plan tests => 6;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $token = $auth->generate_token($admin);

    use Crypt::JWT qw(decode_jwt);
    my $payload = decode_jwt(
        token => $token,
        key => $config->{jwt}{secret_key},
    );

    ok(exists $payload->{sub}, 'Payload contains sub (user ID)');
    ok(exists $payload->{username}, 'Payload contains username');
    ok(exists $payload->{email}, 'Payload contains email');
    ok(exists $payload->{iat}, 'Payload contains iat (issued at)');
    ok(exists $payload->{exp}, 'Payload contains exp (expiration)');

    # Verify expiration is in the future
    ok($payload->{exp} > time(), 'Expiration is in the future');
};

# ============================================================================
# Test: authenticate() updates last_login
# ============================================================================

subtest 'authenticate() updates last_login timestamp' => sub {
    plan tests => 2;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $old_last_login = $admin->last_login;

    # Wait a moment to ensure timestamp changes
    sleep 1;

    # Authenticate
    my $user = $auth->authenticate('admin', 'changeme');

    # Reload admin from database
    $admin->discard_changes;
    my $new_last_login = $admin->last_login;

    ok($new_last_login, 'Last login is set');
    isnt($new_last_login, $old_last_login, 'Last login timestamp was updated');
};

# ============================================================================
# Test: JWT algorithm configuration
# ============================================================================

subtest 'JWT uses configured algorithm' => sub {
    plan tests => 2;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $token = $auth->generate_token($admin);

    # Try to decode with wrong algorithm (should fail)
    use Crypt::JWT qw(decode_jwt);

    # Decode with correct algorithm
    my $payload = decode_jwt(
        token => $token,
        key => $config->{jwt}{secret_key},
        accepted_alg => 'HS256',
    );
    ok($payload, 'Token decodes with correct algorithm (HS256)');
    is($payload->{sub}, $admin->id, 'Payload contains correct user id');
};

# ============================================================================
# Test: Token expiration configuration
# ============================================================================

subtest 'Token expiration respects configuration' => sub {
    plan tests => 2;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $token = $auth->generate_token($admin);

    use Crypt::JWT qw(decode_jwt);
    my $payload = decode_jwt(
        token => $token,
        key => $config->{jwt}{secret_key},
    );

    my $expected_exp = $payload->{iat} + $config->{jwt}{expiration};
    is($payload->{exp}, $expected_exp, 'Expiration matches configured value');

    my $time_until_exp = $payload->{exp} - time();
    ok($time_until_exp > 3500 && $time_until_exp <= 3600, 'Token expires in approximately 1 hour');
};

# ============================================================================
# Test: Security - Password is never returned
# ============================================================================

subtest 'Authenticated user object does not expose password' => sub {
    plan tests => 2;

    my $user = $auth->authenticate('admin', 'changeme');
    ok($user, 'User authenticated');

    # The user object should have password_hash accessor but we're checking
    # that it's the hash, not the plain password
    my $password_hash = $user->password_hash;
    ok($password_hash =~ /^\$2b\$/, 'User object has password hash (not plain password)');
};

# ============================================================================
# Test: Multiple token generation
# ============================================================================

subtest 'Multiple tokens can be generated for same user' => sub {
    plan tests => 4;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });

    my $token1 = $auth->generate_token($admin);
    sleep(1);  # Wait 1 second so iat differs
    my $token2 = $auth->generate_token($admin);

    ok($token1, 'First token generated');
    ok($token2, 'Second token generated');
    isnt($token1, $token2, 'Tokens are different (different iat)');

    # Both tokens should validate
    my $user1 = $auth->validate_token($token1);
    my $user2 = $auth->validate_token($token2);

    ok($user1 && $user2, 'Both tokens validate successfully');
};

# ============================================================================
# Test: Case sensitivity
# ============================================================================

subtest 'Username lookup works (case-insensitive in MySQL by default)' => sub {
    plan tests => 3;

    my $user1 = $auth->authenticate('admin', 'changeme');
    ok($user1, 'Lowercase admin authenticates');

    # Note: MySQL/MariaDB uses case-insensitive collation by default
    # so ADMIN and Admin will also find the user
    my $user2 = $auth->authenticate('ADMIN', 'changeme');
    ok($user2, 'Uppercase ADMIN authenticates (MySQL case-insensitive)');

    my $user3 = $auth->authenticate('Admin', 'changeme');
    ok($user3, 'Mixed case Admin authenticates (MySQL case-insensitive)');
};

# ============================================================================
# Test: Empty and whitespace passwords
# ============================================================================

subtest 'Handles edge cases in passwords' => sub {
    plan tests => 4;

    my $fail1 = $auth->authenticate('admin', '');
    ok(!defined $fail1, 'Empty password fails');

    my $fail2 = $auth->authenticate('admin', '   ');
    ok(!defined $fail2, 'Whitespace password fails');

    my $fail3 = $auth->authenticate('', 'changeme');
    ok(!defined $fail3, 'Empty username fails');

    my $fail4 = $auth->authenticate(undef, undef);
    ok(!defined $fail4, 'Undef credentials fail');
};

# ============================================================================
# Test: Hash password with special characters
# ============================================================================

subtest 'Password hashing works with special characters' => sub {
    plan tests => 6;

    my $passwords = [
        'p@ssw0rd!',
        'пароль',  # Cyrillic
        'contraseña',  # Spanish
        '密码',  # Chinese
        'pass"word\'with<quotes>',
        'multi\nline\npassword',
    ];

    foreach my $password (@$passwords) {
        my $hash = $auth->hash_password($password);
        ok(bcrypt_check($password, $hash), "Hash validates for: $password");
    }
};

# ============================================================================
# Test: Token with missing required config
# ============================================================================

subtest 'Token generation requires secret_key' => sub {
    plan tests => 1;

    my $bad_config = {
        jwt => {
            # Missing secret_key
            algorithm => 'HS256',
        },
    };

    my $bad_auth = PropertyManager::Services::Auth->new(
        schema => $schema,
        config => $bad_config,
    );

    my $admin = $schema->resultset('User')->find({ username => 'admin' });

    eval {
        $bad_auth->generate_token($admin);
    };
    like($@, qr/JWT secret_key not configured/, 'Dies without secret_key');
};

# ============================================================================
# Test: Default configuration values
# ============================================================================

subtest 'Uses default values when config is incomplete' => sub {
    plan tests => 2;

    my $minimal_config = {
        jwt => {
            secret_key => 'test_key',
            # Missing algorithm and expiration
        },
        # Missing app section
    };

    my $minimal_auth = PropertyManager::Services::Auth->new(
        schema => $schema,
        config => $minimal_config,
    );

    my $admin = $schema->resultset('User')->find({ username => 'admin' });

    # Test token generation with defaults
    my $token = $minimal_auth->generate_token($admin);
    ok($token, 'Token generated with default values');

    # Test password hashing with defaults
    my $hash = $minimal_auth->hash_password('test123');
    ok($hash, 'Password hashed with default bcrypt cost');
};

# ============================================================================
# Test: Token validation with wrong secret
# ============================================================================

subtest 'Token validation fails with wrong secret' => sub {
    plan tests => 2;

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $token = $auth->generate_token($admin);

    # Create auth service with different secret
    my $wrong_config = {
        jwt => {
            secret_key => 'different_secret_key',
            algorithm => 'HS256',
        },
    };

    my $wrong_auth = PropertyManager::Services::Auth->new(
        schema => $schema,
        config => $wrong_config,
    );

    my $user = $wrong_auth->validate_token($token);
    ok(!defined $user, 'Token validation fails with wrong secret');

    # But validates with correct secret
    my $correct_user = $auth->validate_token($token);
    ok($correct_user, 'Token validates with correct secret');
};

# ============================================================================
# Test: Long-lived tokens
# ============================================================================

subtest 'Can create long-lived tokens' => sub {
    plan tests => 2;

    my $long_config = {
        jwt => {
            secret_key => 'test_secret',
            algorithm => 'HS256',
            expiration => 2592000,  # 30 days
        },
    };

    my $long_auth = PropertyManager::Services::Auth->new(
        schema => $schema,
        config => $long_config,
    );

    my $admin = $schema->resultset('User')->find({ username => 'admin' });
    my $token = $long_auth->generate_token($admin);

    use Crypt::JWT qw(decode_jwt);
    my $payload = decode_jwt(
        token => $token,
        key => 'test_secret',
    );

    my $time_until_exp = $payload->{exp} - time();
    ok($time_until_exp > 2591000, 'Token has long expiration');
    ok($time_until_exp <= 2592000, 'Token expiration does not exceed configured value');
};

done_testing();
