package PropertyManager::Schema::Result::UtilityCalculation;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::UtilityCalculation - Utility calculation table

=cut

__PACKAGE__->table('utility_calculations');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    period_month => {
        data_type => 'tinyint',
        is_nullable => 0,
    },
    period_year => {
        data_type => 'smallint',
        is_nullable => 0,
    },
    is_finalized => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    finalized_at => {
        data_type => 'datetime',
        is_nullable => 1,
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
__PACKAGE__->add_unique_constraint(period_unique => ['period_month', 'period_year']);

# Relationships
__PACKAGE__->has_many(
    details => 'PropertyManager::Schema::Result::UtilityCalculationDetail',
    'calculation_id'
);

__PACKAGE__->has_many(
    invoices => 'PropertyManager::Schema::Result::Invoice',
    'calculation_id'
);

1;
