package PropertyManager::Schema::Result::Invoice;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::Invoice - Invoice table

=cut

__PACKAGE__->table('invoices');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    invoice_number => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 0,
    },
    invoice_type => {
        data_type => 'enum',
        extra => { list => ['rent', 'utility', 'generic'] },
        is_nullable => 0,
    },
    tenant_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    invoice_date => {
        data_type => 'date',
        is_nullable => 0,
    },
    due_date => {
        data_type => 'date',
        is_nullable => 0,
    },
    exchange_rate => {
        data_type => 'decimal',
        size => [10, 4],
        is_nullable => 1,
    },
    exchange_rate_date => {
        data_type => 'date',
        is_nullable => 1,
    },
    exchange_rate_manual => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    subtotal_eur => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 1,
    },
    subtotal_ron => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
    },
    vat_amount => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
        default_value => 0,
    },
    total_ron => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
    },
    is_paid => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    paid_date => {
        data_type => 'date',
        is_nullable => 1,
    },
    notes => {
        data_type => 'text',
        is_nullable => 1,
    },
    template_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    calculation_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    client_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    client_address => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    client_cui => {
        data_type => 'varchar',
        size => 20,
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
__PACKAGE__->add_unique_constraint(invoice_number_unique => ['invoice_number']);

# Relationships
__PACKAGE__->belongs_to(
    tenant => 'PropertyManager::Schema::Result::Tenant',
    'tenant_id',
    { join_type => 'left' }
);

__PACKAGE__->belongs_to(
    template => 'PropertyManager::Schema::Result::InvoiceTemplate',
    'template_id',
    { join_type => 'left', on_delete => 'SET NULL' }
);

__PACKAGE__->belongs_to(
    calculation => 'PropertyManager::Schema::Result::UtilityCalculation',
    'calculation_id',
    { join_type => 'left', on_delete => 'SET NULL' }
);

__PACKAGE__->has_many(
    items => 'PropertyManager::Schema::Result::InvoiceItem',
    'invoice_id'
);

1;
