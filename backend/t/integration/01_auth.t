#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use HTTP::Request::Common;
use JSON::XS;

# Get test app
my $test = TestHelper::app();

plan tests => 6;

# ============================================================================
# Test: POST /api/auth/login - successful login
# ============================================================================

subtest 'POST /api/auth/login - successful authentication' => sub {
    plan tests => 7;

    my $req = POST '/api/auth/login',
        Content_Type => 'application/json',
        Content => encode_json({
            username => 'admin',
            password => 'changeme',
        });

    my $res = $test->request($req);

    is($res->code, 200, 'Status 200 OK');
    is($res->header('Content-Type'), 'application/json', 'JSON response');

    my $data = decode_json($res->content);

    ok($data->{success}, 'Success flag true');
    ok($data->{data}, 'Data present');
    ok($data->{data}{token}, 'Token present');
    ok($data->{data}{user}, 'User data present');
    is($data->{data}{user}{username}, 'admin', 'Username correct');
};

# ============================================================================
# Test: POST /api/auth/login - invalid credentials
# ============================================================================

subtest 'POST /api/auth/login - invalid credentials' => sub {
    plan tests => 4;

    my $req = POST '/api/auth/login',
        Content_Type => 'application/json',
        Content => encode_json({
            username => 'admin',
            password => 'wrong_password',
        });

    my $res = $test->request($req);

    is($res->code, 401, 'Status 401 Unauthorized');

    my $data = decode_json($res->content);

    ok(!$data->{success}, 'Success flag false');
    ok($data->{error}, 'Error message present');
    is($data->{code}, 'INVALID_CREDENTIALS', 'Error code correct');
};

# ============================================================================
# Test: POST /api/auth/login - missing credentials
# ============================================================================

subtest 'POST /api/auth/login - missing credentials' => sub {
    plan tests => 4;

    my $req = POST '/api/auth/login',
        Content_Type => 'application/json',
        Content => encode_json({});

    my $res = $test->request($req);

    is($res->code, 400, 'Status 400 Bad Request');

    my $data = decode_json($res->content);

    ok(!$data->{success}, 'Success flag false');
    ok($data->{error}, 'Error message present');
    is($data->{code}, 'MISSING_CREDENTIALS', 'Error code correct');
};

# ============================================================================
# Test: GET /api/auth/me - with valid token
# ============================================================================

subtest 'GET /api/auth/me - authenticated request' => sub {
    plan tests => 5;

    my $token = TestHelper::login($test);
    ok($token, 'Login successful');

    my $res = TestHelper::auth_get($test, '/api/auth/me');

    is($res->code, 200, 'Status 200 OK');

    my $data = decode_json($res->content);

    ok($data->{success}, 'Success flag true');
    ok($data->{data}{user}, 'User data present');
    is($data->{data}{user}{username}, 'admin', 'Username correct');
};

# ============================================================================
# Test: GET /api/auth/me - without token
# ============================================================================

subtest 'GET /api/auth/me - unauthenticated request' => sub {
    plan tests => 3;

    my $req = GET '/api/auth/me';
    my $res = $test->request($req);

    is($res->code, 401, 'Status 401 Unauthorized');

    my $data = decode_json($res->content);

    ok(!$data->{success}, 'Success flag false');
    is($data->{code}, 'AUTH_REQUIRED', 'Error code correct');
};

# ============================================================================
# Test: POST /api/auth/logout
# ============================================================================

subtest 'POST /api/auth/logout' => sub {
    plan tests => 2;

    my $token = TestHelper::login($test);

    my $req = POST '/api/auth/logout',
        Authorization => "Bearer $token";

    my $res = $test->request($req);

    is($res->code, 200, 'Status 200 OK');

    my $data = decode_json($res->content);
    ok($data->{success}, 'Logout successful');
};

done_testing();
