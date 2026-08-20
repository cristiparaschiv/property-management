package PropertyManager::Schema::Result::LoanEntry;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::LoanEntry - One movement on a loan

=head1 DESCRIPTION

C<amount> below zero is money advanced, above zero is money repaid. The
outstanding balance is the negated sum of a loan's entries.

=cut

__PACKAGE__->table('loan_entries');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
        extra             => { unsigned => 1 },
    },
    loan_id => {
        data_type   => 'integer',
        is_nullable => 0,
        extra       => { unsigned => 1 },
    },
    entry_date => {
        data_type   => 'date',
        is_nullable => 0,
    },
    label => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 0,
    },
    amount => {
        data_type   => 'decimal',
        size        => [12, 2],
        is_nullable => 0,
    },
    note => {
        data_type   => 'text',
        is_nullable => 1,
    },
    created_at => {
        data_type     => 'timestamp',
        is_nullable   => 1,
        set_on_create => 0,
    },
    updated_at => {
        data_type     => 'timestamp',
        is_nullable   => 1,
        set_on_create => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(
    'uq_loan_entry' => ['loan_id', 'entry_date', 'label', 'amount']);

__PACKAGE__->belongs_to(
    loan => 'PropertyManager::Schema::Result::Loan',
    { 'foreign.id' => 'self.loan_id' },
);

1;
