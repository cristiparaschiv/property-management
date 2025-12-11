#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";

use TestHelper;
use PropertyManager::Services::MeterDifferenceCalculator;

# Get database schema
my $schema = TestHelper::schema();
TestHelper::cleanup_test_data($schema);

plan tests => 8;

# ============================================================================
# Test: Constructor
# ============================================================================

subtest 'Constructor validation' => sub {
    plan tests => 2;

    eval { PropertyManager::Services::MeterDifferenceCalculator->new() };
    like($@, qr/schema is required/, 'Dies without schema');

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);
    isa_ok($calc, 'PropertyManager::Services::MeterDifferenceCalculator');
};

# ============================================================================
# Test: calculate_difference() basic
# ============================================================================

subtest 'calculate_difference() computes correctly' => sub {
    plan tests => 7;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    # Get or create General meter
    my $general = $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first;
    unless ($general) {
        $general = $schema->resultset('ElectricityMeter')->create({
            name => 'General',
            is_general => 1,
            is_active => 1,
        });
    }

    # Create tenant meters
    my $meter1 = TestHelper::create_test_meter($schema, name => 'Meter 1', is_general => 0);
    my $meter2 = TestHelper::create_test_meter($schema, name => 'Meter 2', is_general => 0);

    # Create readings for December 2025
    # General: 1500 kWh
    TestHelper::create_test_meter_reading($schema,
        meter_id => $general->id,
        period_year => 2025,
        period_month => 12,
        consumption => 1500.00,
    );

    # Meter 1: 800 kWh
    TestHelper::create_test_meter_reading($schema,
        meter_id => $meter1->id,
        period_year => 2025,
        period_month => 12,
        consumption => 800.00,
    );

    # Meter 2: 400 kWh
    TestHelper::create_test_meter_reading($schema,
        meter_id => $meter2->id,
        period_year => 2025,
        period_month => 12,
        consumption => 400.00,
    );

    my $result = $calc->calculate_difference(2025, 12);

    ok($result, 'Result returned');
    is($result->{general_consumption}, '1500.00', 'General consumption');
    is($result->{tenant_meters_total}, '1200.00', 'Tenant meters total (800 + 400)');
    is($result->{difference}, '300.00', 'Difference (1500 - 1200)');
    is($result->{period_month}, 12, 'Period month');
    is($result->{period_year}, 2025, 'Period year');

    my @tenant_meters = @{$result->{tenant_meters}};
    is(scalar @tenant_meters, 2, 'Two tenant meters in result');
};

# ============================================================================
# Test: calculate_difference() with no tenant meters
# ============================================================================

subtest 'calculate_difference() with no tenant meters' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    # Delete tenant meter readings
    $schema->resultset('MeterReading')->search({
        meter_id => { '!=' => $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first->id }
    })->delete;

    my $general = $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first;

    TestHelper::create_test_meter_reading($schema,
        meter_id => $general->id,
        period_year => 2025,
        period_month => 11,
        consumption => 1000.00,
    );

    my $result = $calc->calculate_difference(2025, 11);

    is($result->{general_consumption}, '1000.00', 'General consumption');
    is($result->{tenant_meters_total}, '0.00', 'No tenant meters');
    is($result->{difference}, '1000.00', 'Difference equals general consumption');
};

# ============================================================================
# Test: calculate_difference() with missing general reading
# ============================================================================

subtest 'calculate_difference() with missing general reading' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    my $result = $calc->calculate_difference(2025, 10);

    ok($result, 'Returns result even without general reading');
    is($result->{general_consumption}, '0.00', 'General consumption is 0');
    is($result->{tenant_meters_total}, '0.00', 'Tenant meters total is 0');
};

# ============================================================================
# Test: calculate_difference() parameter validation
# ============================================================================

subtest 'calculate_difference() validates parameters' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    eval {
        $calc->calculate_difference();
    };
    like($@, qr/year and month are required/, 'Dies without parameters');

    eval {
        $calc->calculate_difference(2025);
    };
    like($@, qr/year and month are required/, 'Dies without month');

    eval {
        $calc->calculate_difference(undef, 12);
    };
    like($@, qr/year and month are required/, 'Dies without year');
};

# ============================================================================
# Test: calculate_difference() only includes active meters
# ============================================================================

subtest 'calculate_difference() only uses active meters' => sub {
    plan tests => 2;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    # Create inactive meter
    my $inactive_meter = TestHelper::create_test_meter($schema,
        name => 'Inactive Meter',
        is_general => 0,
        is_active => 0,
    );

    TestHelper::create_test_meter_reading($schema,
        meter_id => $inactive_meter->id,
        period_year => 2025,
        period_month => 9,
        consumption => 999.00,
    );

    my $general = $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first;
    TestHelper::create_test_meter_reading($schema,
        meter_id => $general->id,
        period_year => 2025,
        period_month => 9,
        consumption => 1500.00,
    );

    my $result = $calc->calculate_difference(2025, 9);

    # Should not include inactive meter's consumption
    is($result->{tenant_meters_total}, '0.00', 'Inactive meters not included');
    is($result->{difference}, '1500.00', 'Difference does not include inactive meter');
};

# ============================================================================
# Test: calculate_difference() with negative difference
# ============================================================================

subtest 'calculate_difference() handles negative difference' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    my $general = $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first;

    # General: 500 kWh
    TestHelper::create_test_meter_reading($schema,
        meter_id => $general->id,
        period_year => 2025,
        period_month => 8,
        consumption => 500.00,
    );

    # Tenant meter with more than general (unusual but possible)
    my $meter = TestHelper::create_test_meter($schema, name => 'High Meter');
    TestHelper::create_test_meter_reading($schema,
        meter_id => $meter->id,
        period_year => 2025,
        period_month => 8,
        consumption => 800.00,
    );

    my $result = $calc->calculate_difference(2025, 8);

    is($result->{general_consumption}, '500.00', 'General consumption');
    is($result->{tenant_meters_total}, '800.00', 'Tenant meters total');
    is($result->{difference}, '-300.00', 'Negative difference handled');
};

# ============================================================================
# Test: calculate_difference() with decimal consumption
# ============================================================================

subtest 'calculate_difference() handles decimal values' => sub {
    plan tests => 3;

    my $calc = PropertyManager::Services::MeterDifferenceCalculator->new(schema => $schema);

    my $general = $schema->resultset('ElectricityMeter')->search({ is_general => 1 })->first;

    TestHelper::create_test_meter_reading($schema,
        meter_id => $general->id,
        period_year => 2025,
        period_month => 7,
        consumption => 1234.56,
    );

    my $meter1 = TestHelper::create_test_meter($schema, name => 'Decimal 1');
    TestHelper::create_test_meter_reading($schema,
        meter_id => $meter1->id,
        period_year => 2025,
        period_month => 7,
        consumption => 789.12,
    );

    my $meter2 = TestHelper::create_test_meter($schema, name => 'Decimal 2');
    TestHelper::create_test_meter_reading($schema,
        meter_id => $meter2->id,
        period_year => 2025,
        period_month => 7,
        consumption => 123.45,
    );

    my $result = $calc->calculate_difference(2025, 7);

    is($result->{general_consumption}, '1234.56', 'General with decimals');
    is($result->{tenant_meters_total}, '912.57', 'Tenant total with decimals');
    is($result->{difference}, '321.99', 'Difference with decimals');
};

TestHelper::cleanup_test_data($schema);
done_testing();
