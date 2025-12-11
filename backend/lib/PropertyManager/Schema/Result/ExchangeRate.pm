package PropertyManager::Schema::Result::ExchangeRate;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::ExchangeRate - Exchange rate table

=cut

__PACKAGE__->table('exchange_rates');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    rate_date => {
        data_type => 'date',
        is_nullable => 0,
    },
    eur_ron => {
        data_type => 'decimal',
        size => [10, 4],
        is_nullable => 0,
    },
    source => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 0,
        default_value => 'BNR',
    },
    created_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(rate_date_unique => ['rate_date']);

1;
