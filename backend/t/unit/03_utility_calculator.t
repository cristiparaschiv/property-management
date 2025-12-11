#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::UtilityCalculator;

# Get database schema
my $schema = TestHelper::schema();

# Clean up test data before starting
TestHelper::cleanup_test_data($schema);

# Test plan
plan tests => 10;

# ============================================================================
# Test: Constructor
# ============================================================================

subtest 'Constructor requires schema' => sub {
    plan tests => 2;

    eval {
        PropertyManager::Services::UtilityCalculator->new();
    };
    like($@, qr/schema is required/, 'Dies without schema');

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);
    isa_ok($calc, 'PropertyManager::Services::UtilityCalculator', 'Creates instance');
};

# ============================================================================
# Test: get_invoices_for_period()
# ============================================================================

subtest 'get_invoices_for_period() finds invoices' => sub {
    plan tests => 5;

    # Clean up existing invoices first
    $schema->resultset('ReceivedInvoice')->delete_all;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    # Create test invoices
    my $inv1 = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity',
        period_start => '2025-12-01',
        period_end => '2025-12-31',
        amount => 1000.00,
    );

    my $inv2 = TestHelper::create_test_received_invoice($schema,
        utility_type => 'water',
        period_start => '2025-12-01',
        period_end => '2025-12-31',
        amount => 500.00,
    );

    my $inv3 = TestHelper::create_test_received_invoice($schema,
        utility_type => 'gas',
        period_start => '2025-11-01',  # Different month
        period_end => '2025-11-30',
        amount => 300.00,
    );

    my @invoices = $calc->get_invoices_for_period(2025, 12);

    is(scalar @invoices, 2, 'Found 2 invoices for December');
    ok((grep { $_->id == $inv1->id } @invoices), 'Found electricity invoice');
    ok((grep { $_->id == $inv2->id } @invoices), 'Found water invoice');
    ok(!(grep { $_->id == $inv3->id } @invoices), 'November invoice not included');

    # Test empty result
    my @empty = $calc->get_invoices_for_period(2026, 1);
    is(scalar @empty, 0, 'Returns empty array for period with no invoices');
};

# ============================================================================
# Test: calculate_shares() basic calculation
# ============================================================================

subtest 'calculate_shares() distributes costs correctly' => sub {
    plan tests => 8;

    # Clean up existing data
    $schema->resultset('ReceivedInvoice')->delete_all;
    $schema->resultset('TenantUtilityPercentage')->delete_all;
    $schema->resultset('Tenant')->delete_all;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    # Create tenants with percentages
    my $tenant1 = TestHelper::create_test_tenant($schema,
        name => 'Tenant A',
        with_percentages => 1,
        percentages => {
            electricity => 40.00,
            water => 30.00,
        },
    );

    my $tenant2 = TestHelper::create_test_tenant($schema,
        name => 'Tenant B',
        with_percentages => 1,
        percentages => {
            electricity => 30.00,
            water => 40.00,
        },
    );

    # Create received invoice
    my $invoice = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity',
        period_start => '2025-12-01',
        period_end => '2025-12-31',
        amount => 1000.00,
    );

    # Calculate shares
    my $result = $calc->calculate_shares(year => 2025, month => 12);

    ok($result, 'Returns result');
    is($result->{period_month}, 12, 'Period month correct');
    is($result->{period_year}, 2025, 'Period year correct');
    is($result->{total_invoices}, 1, 'Total invoices count correct');

    # Check tenant shares
    my @tenant_details = @{$result->{tenant_shares}};
    is(scalar @tenant_details, 2, 'Two tenants in result');

    my ($detail_a) = grep { $_->{tenant_id} == $tenant1->id } @tenant_details;
    my ($detail_b) = grep { $_->{tenant_id} == $tenant2->id } @tenant_details;

    is($detail_a->{utilities}{electricity}{amount}, '400.00', 'Tenant A gets 40% (400)');
    is($detail_b->{utilities}{electricity}{amount}, '300.00', 'Tenant B gets 30% (300)');

    # Company portion should be 30% (100% - 40% - 30%)
    is($result->{company_portion}{total}, '300.00', 'Company gets remaining 30% (300)');
};

# ============================================================================
# Test: calculate_shares() with multiple utility types
# ============================================================================

subtest 'calculate_shares() handles multiple utility types' => sub {
    plan tests => 7;

    # Clean up existing data
    $schema->resultset('ReceivedInvoice')->delete_all;
    $schema->resultset('TenantUtilityPercentage')->delete_all;
    $schema->resultset('Tenant')->delete_all;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    # Create tenants with percentages
    my $tenant1 = TestHelper::create_test_tenant($schema,
        name => 'Tenant A',
        with_percentages => 1,
        percentages => {
            electricity => 40.00,
            water => 30.00,
        },
    );

    my $tenant2 = TestHelper::create_test_tenant($schema,
        name => 'Tenant B',
        with_percentages => 1,
        percentages => {
            electricity => 30.00,
            water => 40.00,
        },
    );

    # Create multiple utility invoices
    my $elec_inv = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity',
        period_start => '2025-11-01',
        period_end => '2025-11-30',
        amount => 1000.00,
    );

    my $water_inv = TestHelper::create_test_received_invoice($schema,
        utility_type => 'water',
        period_start => '2025-11-01',
        period_end => '2025-11-30',
        amount => 500.00,
    );

    my $result = $calc->calculate_shares(year => 2025, month => 11);

    is($result->{total_invoices}, 2, 'Two invoices processed');

    my ($detail_a) = grep { $_->{tenant_id} == $tenant1->id } @{$result->{tenant_shares}};

    # Tenant A: 40% electricity + 30% water
    is($detail_a->{utilities}{electricity}{amount}, '400.00', 'Tenant A electricity: 400');
    is($detail_a->{utilities}{water}{amount}, '150.00', 'Tenant A water: 150');
    is($detail_a->{total_amount}, '550.00', 'Tenant A total: 550');

    # Company portion
    my @company_utils = @{$result->{company_portion}{by_utility}};
    is(scalar @company_utils, 2, 'Company has 2 utility types');

    my ($company_elec) = grep { $_->{utility_type} eq 'electricity' } @company_utils;
    my ($company_water) = grep { $_->{utility_type} eq 'water' } @company_utils;

    is($company_elec->{amount}, '300.00', 'Company electricity portion: 300');
    is($company_water->{amount}, '150.00', 'Company water portion: 150');
};

# ============================================================================
# Test: calculate_shares() with percentage overrides
# ============================================================================

subtest 'calculate_shares() applies percentage overrides' => sub {
    plan tests => 4;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    my $tenant1 = $schema->resultset('Tenant')->search({ name => 'Tenant A' })->first;
    my $tenant2 = $schema->resultset('Tenant')->search({ name => 'Tenant B' })->first;

    # Invoice for testing
    my $invoice = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity',
        period_start => '2025-10-01',
        period_end => '2025-10-31',
        amount => 1000.00,
    );

    # Override Tenant A's electricity to 50% (default was 40%)
    my $result = $calc->calculate_shares(
        year => 2025,
        month => 10,
        overrides => {
            $tenant1->id => {
                electricity => 50.00,
            },
        },
    );

    my ($detail_a) = grep { $_->{tenant_id} == $tenant1->id } @{$result->{tenant_shares}};
    my ($detail_b) = grep { $_->{tenant_id} == $tenant2->id } @{$result->{tenant_shares}};

    is($detail_a->{utilities}{electricity}{amount}, '500.00', 'Override applied: Tenant A gets 50%');
    is($detail_a->{utilities}{electricity}{percentage}, '50.00', 'Override percentage stored');
    is($detail_b->{utilities}{electricity}{amount}, '300.00', 'Tenant B unchanged at 30%');
    is($result->{company_portion}{total}, '200.00', 'Company gets remaining 20%');
};

# ============================================================================
# Test: calculate_shares() with no tenants
# ============================================================================

subtest 'calculate_shares() handles no active tenants' => sub {
    plan tests => 3;

    # Clean up tenants
    $schema->resultset('TenantUtilityPercentage')->delete_all;
    $schema->resultset('Tenant')->update_all({ is_active => 0 });

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    my $invoice = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity',
        period_start => '2025-09-01',
        period_end => '2025-09-30',
        amount => 1000.00,
    );

    my $result = $calc->calculate_shares(year => 2025, month => 9);

    is(scalar @{$result->{tenant_shares}}, 0, 'No tenant shares');
    is($result->{company_portion}{total}, '1000.00', 'Company gets 100%');
    is($result->{total_invoices}, 1, 'Invoice still processed');

    # Restore tenants for other tests
    $schema->resultset('Tenant')->update_all({ is_active => 1 });
};

# ============================================================================
# Test: calculate_shares() with zero percentages
# ============================================================================

subtest 'calculate_shares() handles zero percentages' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    my $tenant = TestHelper::create_test_tenant($schema,
        name => 'Tenant Zero',
        with_percentages => 1,
        percentages => {
            electricity => 0.00,
        },
    );

    my $invoice = TestHelper::create_test_received_invoice($schema,
        utility_type => 'electricity',
        period_start => '2025-08-01',
        period_end => '2025-08-31',
        amount => 1000.00,
    );

    my $result = $calc->calculate_shares(year => 2025, month => 8);

    my ($detail) = grep { $_->{tenant_id} == $tenant->id } @{$result->{tenant_shares}};

    ok($detail, 'Tenant present in results');
    ok(!exists $detail->{utilities}{electricity}, 'No electricity share for 0%');
    is($detail->{total_amount}, '0.00', 'Tenant total is 0');
};

# ============================================================================
# Test: calculate_shares() with missing percentages
# ============================================================================

subtest 'calculate_shares() handles missing percentage records' => sub {
    plan tests => 2;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    my $tenant = TestHelper::create_test_tenant($schema,
        name => 'Tenant No Pct',
        with_percentages => 0,  # No percentages defined
    );

    my $invoice = TestHelper::create_test_received_invoice($schema,
        utility_type => 'gas',
        period_start => '2025-07-01',
        period_end => '2025-07-31',
        amount => 800.00,
    );

    my $result = $calc->calculate_shares(year => 2025, month => 7);

    my ($detail) = grep { $_->{tenant_id} == $tenant->id } @{$result->{tenant_shares}};

    is($detail->{total_amount}, '0.00', 'Tenant with no percentages gets 0');
    is($result->{company_portion}{total}, '800.00', 'Company gets all when no percentages defined');
};

# ============================================================================
# Test: calculate_shares() validates parameters
# ============================================================================

subtest 'calculate_shares() validates required parameters' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    eval {
        $calc->calculate_shares();
    };
    like($@, qr/year and month are required/, 'Dies without parameters');

    eval {
        $calc->calculate_shares(year => 2025);
    };
    like($@, qr/year and month are required/, 'Dies without month');

    eval {
        $calc->calculate_shares(month => 12);
    };
    like($@, qr/year and month are required/, 'Dies without year');
};

# ============================================================================
# Test: Complex scenario with overlapping periods
# ============================================================================

subtest 'calculate_shares() handles overlapping invoice periods' => sub {
    plan tests => 2;

    my $calc = PropertyManager::Services::UtilityCalculator->new(schema => $schema);

    # Invoice that spans multiple months
    my $invoice = TestHelper::create_test_received_invoice($schema,
        utility_type => 'internet',
        period_start => '2025-06-15',
        period_end => '2025-07-14',
        amount => 600.00,
    );

    # Should be found for both June and July
    my @june_invoices = $calc->get_invoices_for_period(2025, 6);
    my @july_invoices = $calc->get_invoices_for_period(2025, 7);

    ok((grep { $_->id == $invoice->id } @june_invoices), 'Invoice found in June');
    ok((grep { $_->id == $invoice->id } @july_invoices), 'Invoice found in July');
};

# Clean up
TestHelper::cleanup_test_data($schema);

done_testing();
