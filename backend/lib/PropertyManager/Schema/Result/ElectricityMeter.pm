package PropertyManager::Schema::Result::ElectricityMeter;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::ElectricityMeter - Electricity meter table

=cut

__PACKAGE__->table('electricity_meters');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    name => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 0,
    },
    location => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    tenant_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    is_general => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    meter_number => {
        data_type => 'varchar',
        size => 100,
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
__PACKAGE__->belongs_to(
    tenant => 'PropertyManager::Schema::Result::Tenant',
    'tenant_id',
    { join_type => 'left', on_delete => 'SET NULL' }
);

__PACKAGE__->has_many(
    readings => 'PropertyManager::Schema::Result::MeterReading',
    'meter_id'
);

1;
