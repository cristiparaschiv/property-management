package PropertyManager::Schema::Result::MeteredCalculationInput;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::MeteredCalculationInput - Metered calculation input table

=cut

__PACKAGE__->table('metered_calculation_inputs');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    calculation_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    received_invoice_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    utility_type => {
        data_type => 'enum',
        extra => { list => ['gas', 'water'] },
        is_nullable => 0,
    },
    total_units => {
        data_type => 'decimal',
        size => [12, 2],
        is_nullable => 0,
    },
    consumption_amount => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 1,
    },
    rain_amount => {
        data_type => 'decimal',
        size => [10, 2],
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
__PACKAGE__->add_unique_constraint(calc_utility_unique => ['calculation_id', 'utility_type']);

# Relationships
__PACKAGE__->belongs_to(
    calculation => 'PropertyManager::Schema::Result::UtilityCalculation',
    'calculation_id'
);

__PACKAGE__->belongs_to(
    received_invoice => 'PropertyManager::Schema::Result::ReceivedInvoice',
    'received_invoice_id'
);

1;
