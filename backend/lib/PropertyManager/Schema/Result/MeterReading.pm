package PropertyManager::Schema::Result::MeterReading;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::MeterReading - Meter reading table

=cut

__PACKAGE__->table('meter_readings');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    meter_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    reading_date => {
        data_type => 'date',
        is_nullable => 0,
    },
    reading_value => {
        data_type => 'decimal',
        size => [12, 2],
        is_nullable => 0,
    },
    previous_reading_value => {
        data_type => 'decimal',
        size => [12, 2],
        is_nullable => 1,
    },
    consumption => {
        data_type => 'decimal',
        size => [12, 2],
        is_nullable => 1,
    },
    period_month => {
        data_type => 'tinyint',
        is_nullable => 0,
    },
    period_year => {
        data_type => 'smallint',
        is_nullable => 0,
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
__PACKAGE__->add_unique_constraint(meter_period_unique => ['meter_id', 'period_month', 'period_year']);

# Relationships
__PACKAGE__->belongs_to(
    meter => 'PropertyManager::Schema::Result::ElectricityMeter',
    'meter_id'
);

1;
