package PropertyManager::Schema::Result::InvoiceItem;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::InvoiceItem - Invoice item table

=cut

__PACKAGE__->table('invoice_items');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    invoice_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    description => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    quantity => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
        default_value => 1,
    },
    unit_price => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
    },
    vat_rate => {
        data_type => 'decimal',
        size => [5, 2],
        is_nullable => 0,
        default_value => 0,
    },
    total => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
    },
    sort_order => {
        data_type => 'integer',
        is_nullable => 0,
        default_value => 0,
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
    invoice => 'PropertyManager::Schema::Result::Invoice',
    'invoice_id'
);

1;
