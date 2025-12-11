package PropertyManager::Schema::Result::UtilityProvider;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::UtilityProvider - Utility provider table

=cut

__PACKAGE__->table('utility_providers');

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
    type => {
        data_type => 'enum',
        extra => { list => ['electricity', 'gas', 'water', 'salubrity', 'internet', 'other'] },
        is_nullable => 0,
    },
    account_number => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 1,
    },
    address => {
        data_type => 'varchar',
        size => 255,
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
    notes => {
        data_type => 'text',
        is_nullable => 1,
    },
    is_active => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 1,
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
    received_invoices => 'PropertyManager::Schema::Result::ReceivedInvoice',
    'provider_id'
);

1;
