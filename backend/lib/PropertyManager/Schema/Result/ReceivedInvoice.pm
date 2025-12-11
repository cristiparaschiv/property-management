package PropertyManager::Schema::Result::ReceivedInvoice;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::ReceivedInvoice - Received invoice table

=cut

__PACKAGE__->table('received_invoices');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    provider_id => {
        data_type => 'integer',
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    invoice_number => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 0,
    },
    invoice_date => {
        data_type => 'date',
        is_nullable => 0,
    },
    due_date => {
        data_type => 'date',
        is_nullable => 0,
    },
    amount => {
        data_type => 'decimal',
        size => [10, 2],
        is_nullable => 0,
    },
    utility_type => {
        data_type => 'enum',
        extra => { list => ['electricity', 'gas', 'water', 'salubrity', 'internet', 'other'] },
        is_nullable => 0,
    },
    period_start => {
        data_type => 'date',
        is_nullable => 0,
    },
    period_end => {
        data_type => 'date',
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
    provider => 'PropertyManager::Schema::Result::UtilityProvider',
    'provider_id'
);

__PACKAGE__->has_many(
    calculation_details => 'PropertyManager::Schema::Result::UtilityCalculationDetail',
    'received_invoice_id'
);

1;
