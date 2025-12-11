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

TestHelper::cleanup_test_data($schema);

plan tests => 7;

# ============================================================================
# Test: GET /api/tenants - list tenants
# ============================================================================

subtest 'GET /api/tenants - list all tenants' => sub {
    plan tests => 3;

    my $res = TestHelper::auth_get($test, '/api/tenants');

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');
    ok(ref $data->{data}{tenants} eq 'ARRAY', 'Tenants array returned');
};

# ============================================================================
# Test: POST /api/tenants - create tenant
# ============================================================================

subtest 'POST /api/tenants - create new tenant' => sub {
    plan tests => 8;

    my $tenant_data = {
        name => 'Integration Test Tenant',
        address => '789 Tenant St',
        city => 'Bucharest',
        county => 'Bucharest',
        email => 'tenant@test.com',
        phone => '0721234567',
        rent_amount_eur => 500.00,
        contract_start => '2025-01-01',
        contract_end => '2026-01-01',
        is_active => 1,
    };

    my $res = TestHelper::auth_post($test, '/api/tenants', $tenant_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);

    ok($data->{success}, 'Success flag true');
    ok($data->{data}{tenant}, 'Tenant data present');
    ok($data->{data}{tenant}{id}, 'Tenant ID assigned');
    is($data->{data}{tenant}{name}, 'Integration Test Tenant', 'Tenant name correct');
    ok(abs($data->{data}{tenant}{rent_amount_eur} - 500.00) < 0.01, 'Rent amount correct');
    is($data->{data}{tenant}{is_active}, 1, 'Is active flag correct');

    # Store tenant ID for later tests
    $test->{tenant_id} = $data->{data}{tenant}{id};
    ok($test->{tenant_id}, 'Tenant ID stored');
};

# ============================================================================
# Test: GET /api/tenants/:id - get single tenant
# ============================================================================

subtest 'GET /api/tenants/:id - retrieve specific tenant' => sub {
    plan tests => 5;

    my $tenant_id = $test->{tenant_id};
    my $res = TestHelper::auth_get($test, "/api/tenants/$tenant_id");

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);

    ok($data->{success}, 'Success flag true');
    is($data->{data}{tenant}{id}, $tenant_id, 'Tenant ID matches');
    is($data->{data}{tenant}{name}, 'Integration Test Tenant', 'Tenant name matches');
    ok(exists $data->{data}{tenant}{percentages}, 'Percentages included');
};

# ============================================================================
# Test: PUT /api/tenants/:id - update tenant
# ============================================================================

subtest 'PUT /api/tenants/:id - update tenant' => sub {
    plan tests => 4;

    my $tenant_id = $test->{tenant_id};
    my $update_data = {
        name => 'Updated Tenant Name',
        rent_amount_eur => 600.00,
        phone => '0721234568',
    };

    my $res = TestHelper::auth_put($test, "/api/tenants/$tenant_id", $update_data);

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);

    ok($data->{success}, 'Success flag true');
    is($data->{data}{tenant}{name}, 'Updated Tenant Name', 'Name updated');
    ok(abs($data->{data}{tenant}{rent_amount_eur} - 600.00) < 0.01, 'Rent updated');
};

# ============================================================================
# Test: PUT /api/tenants/:id/percentages - update utility percentages
# ============================================================================

subtest 'PUT /api/tenants/:id/percentages - update percentages' => sub {
    plan tests => 5;

    my $tenant_id = $test->{tenant_id};
    my $percentages = {
        electricity => 40.00,
        gas => 35.00,
        water => 30.00,
        salubrity => 40.00,
    };

    my $res = TestHelper::auth_put($test, "/api/tenants/$tenant_id/percentages", { percentages => $percentages });

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);

    ok($data->{success}, 'Success flag true');
    is($data->{data}{percentages}{electricity}, 40.00, 'Electricity percentage set');
    is($data->{data}{percentages}{gas}, 35.00, 'Gas percentage set');
    is($data->{data}{percentages}{water}, 30.00, 'Water percentage set');
};

# ============================================================================
# Test: DELETE /api/tenants/:id - soft delete (deactivate) tenant
# ============================================================================

subtest 'DELETE /api/tenants/:id - soft delete tenant' => sub {
    plan tests => 5;

    my $tenant_id = $test->{tenant_id};

    my $res = TestHelper::auth_delete($test, "/api/tenants/$tenant_id");

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');

    # Verify tenant is deactivated
    my $get_res = TestHelper::auth_get($test, "/api/tenants/$tenant_id");
    my $get_data = TestHelper::decode_response($get_res);

    is($get_data->{data}{tenant}{is_active}, 0, 'Tenant is inactive');

    # Verify tenant still exists in database
    my $tenant = $schema->resultset('Tenant')->find($tenant_id);
    ok($tenant, 'Tenant still in database');
    is($tenant->is_active, 0, 'is_active flag set to 0');
};

# ============================================================================
# Test: GET /api/tenants - filter by active status
# ============================================================================

subtest 'GET /api/tenants - filter by active status' => sub {
    plan tests => 4;

    # Create an active tenant
    my $active_tenant = TestHelper::create_test_tenant($schema,
        name => 'Active Tenant',
        is_active => 1,
    );

    # Get active tenants
    my $res = TestHelper::auth_get($test, '/api/tenants?is_active=1');

    is($res->code, 200, 'Status 200 OK');

    my $data = TestHelper::decode_response($res);
    ok($data->{success}, 'Success flag true');

    my @tenants = @{$data->{data}{tenants}};
    ok(scalar @tenants > 0, 'At least one active tenant');
    ok((grep { $_->{id} == $active_tenant->id } @tenants), 'Active tenant in results');
};

TestHelper::cleanup_test_data($schema);
done_testing();
