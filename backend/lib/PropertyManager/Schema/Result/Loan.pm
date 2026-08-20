package PropertyManager::Schema::Result::Loan;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::Loan - Personal loan ledger

=head1 DESCRIPTION

Money lent to a person and paid back over time. C<offset_rate> is an optional
monthly amount credited against the debt (accounting services, for example);
zero disables it.

=cut

__PACKAGE__->table('loans');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
        extra             => { unsigned => 1 },
    },
    person => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 0,
    },
    currency => {
        data_type     => 'char',
        size          => 3,
        is_nullable   => 0,
        default_value => 'RON',
    },
    offset_label => {
        data_type   => 'varchar',
        size        => 100,
        is_nullable => 1,
    },
    offset_rate => {
        data_type     => 'decimal',
        size          => [10, 2],
        is_nullable   => 0,
        default_value => 0,
    },
    offset_start => {
        data_type   => 'date',
        is_nullable => 1,
    },
    notes => {
        data_type   => 'text',
        is_nullable => 1,
    },
    is_active => {
        data_type     => 'tinyint',
        is_nullable   => 0,
        default_value => 1,
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
__PACKAGE__->add_unique_constraint('uq_loan_person' => ['person']);

__PACKAGE__->has_many(
    entries => 'PropertyManager::Schema::Result::LoanEntry',
    { 'foreign.loan_id' => 'self.id' },
    { cascade_delete => 1 },
);

1;
