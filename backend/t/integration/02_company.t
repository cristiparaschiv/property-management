#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use JSON::XS;

my $test = TestHelper::app();
my $schema = TestHelper::schema();

plan tests => 4;

# ============================================================================
# Test: GET /api/company - get company info
# ============================================================================

subtest 'GET /api/company - retrieve company' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_get($test, '/api/company');

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    ok($data->{data}{company} || exists $data->{error}, 'Company data or 404');
};

# ============================================================================
# Test: POST /api/company - create company
# ============================================================================

subtest 'POST /api/company - create company' => sub {
    plan tests => 6;

    # Delete existing company if any
    $schema->resultset('Company')->delete_all;

    my $company_data = {
        name => 'Test Property Management SRL',
        cui_cif => 'RO12345678',
        j_number => 'J40/1234/2025',
        address => '123 Test Street',
        city => 'Bucharest',
        county => 'Bucharest',
        postal_code => '012345',
        bank_name => 'Test Bank',
        iban => 'RO49AAAA1B31007593840000',
        phone => '0212345678',
        email => 'company@test.com',
    };

    my $res = TestHelper::auth_post($test, '/api/company', $company_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);

    ok($data->{success}, 'Success flag true');
    ok($data->{data}{company}, 'Company data present');
    is($data->{data}{company}{name}, 'Test Property Management SRL', 'Company name correct');
    is($data->{data}{company}{cui_cif}, 'RO12345678', 'CUI/CIF correct');
    is($data->{data}{company}{city}, 'Bucharest', 'City correct');
};

# ============================================================================
# Test: PUT /api/company - update company
# ============================================================================

subtest 'PUT /api/company - update company' => sub {
    plan tests => 4;

    my $update_data = {
        name => 'Updated Property Management SRL',
        phone => '0212345679',
    };

    my $res = TestHelper::auth_put($test, '/api/company', $update_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);

    ok($data->{success}, 'Success flag true');
    is($data->{data}{company}{name}, 'Updated Property Management SRL', 'Name updated');
    is($data->{data}{company}{phone}, '0212345679', 'Phone updated');
};

# ============================================================================
# Test: POST /api/company - cannot create second company
# ============================================================================

subtest 'POST /api/company - only one company allowed' => sub {
    plan tests => 2;

    my $company_data = {
        name => 'Second Company',
        cui_cif => 'RO99999999',
        address => '456 Test Ave',
        city => 'Cluj',
        county => 'Cluj',
    };

    my $res = TestHelper::auth_post($test, '/api/company', $company_data);

    is($res->code, 400, 'Status 400 Bad Request');

    my $data = TestHelper::decode_response($res);
    ok(!$data->{success}, 'Success flag false');
};

done_testing();
