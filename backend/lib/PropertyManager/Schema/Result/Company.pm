package PropertyManager::Schema::Result::Company;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::Company - Company information table

=cut

__PACKAGE__->table('company');

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
    cui_cif => {
        data_type => 'varchar',
        size => 20,
        is_nullable => 0,
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
    bank_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    iban => {
        data_type => 'varchar',
        size => 50,
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
    representative_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    invoice_prefix => {
        data_type => 'varchar',
        size => 10,
        is_nullable => 1,
        default_value => 'ARC',
    },
    last_invoice_number => {
        data_type => 'integer',
        is_nullable => 1,
        default_value => 0,
    },
    balance => {
        data_type => 'decimal',
        size => [12, 2],
        is_nullable => 0,
        default_value => 0.00,
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

1;
