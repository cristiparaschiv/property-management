package PropertyManager::Schema::Result::Tenant;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::Tenant - Tenant information table

=cut

__PACKAGE__->table('tenants');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    cui_cnp => {
        data_type => 'varchar',
        size => 20,
        is_nullable => 1,
    },
    j_number => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 1,
    },
    address => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    city => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 0,
    },
    county => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 0,
    },
    postal_code => {
        data_type => 'varchar',
        size => 20,
        is_nullable => 1,
    },
    phone => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 1,
    },
    email => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    rent_amount_eur => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
        default_value => 0,
    },
    contract_start => {
        data_type => 'date',
        is_nullable => 1,
    },
    contract_end => {
        data_type => 'date',
        is_nullable => 1,
    },
    is_active => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 1,
    },
    notes => {
        data_type => 'text',
        is_nullable => 1,
    },
    created_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP',
    },
    updated_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');

# Relationships
__PACKAGE__->has_many(
    utility_percentages => 'PropertyManager::Schema::Result::TenantUtilityPercentage',
    'tenant_id'
);

__PACKAGE__->has_many(
    invoices => 'PropertyManager::Schema::Result::Invoice',
    'tenant_id'
);

__PACKAGE__->has_many(
    meters => 'PropertyManager::Schema::Result::ElectricityMeter',
    'tenant_id'
);

__PACKAGE__->has_many(
    calculation_details => 'PropertyManager::Schema::Result::UtilityCalculationDetail',
    'tenant_id'
);

1;
