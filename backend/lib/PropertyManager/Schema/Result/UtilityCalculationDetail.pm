package PropertyManager::Schema::Result::UtilityCalculationDetail;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::UtilityCalculationDetail - Utility calculation detail table

=cut

__PACKAGE__->table('utility_calculation_details');

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
    tenant_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    utility_type => {
        data_type => 'enum',
        extra => { list => ['electricity', 'gas', 'water', 'salubrity', 'internet', 'other'] },
        is_nullable => 0,
    },
    received_invoice_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    percentage => {
        data_type => 'decimal',
        size => [5, 2],
        is_nullable => 0,
    },
    amount => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
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
    calculation => 'PropertyManager::Schema::Result::UtilityCalculation',
    'calculation_id'
);

__PACKAGE__->belongs_to(
    tenant => 'PropertyManager::Schema::Result::Tenant',
    'tenant_id'
);

__PACKAGE__->belongs_to(
    received_invoice => 'PropertyManager::Schema::Result::ReceivedInvoice',
    'received_invoice_id',
    { join_type => 'left', on_delete => 'SET NULL' }
);

1;
