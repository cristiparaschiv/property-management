package PropertyManager::Schema::Result::InvoiceTemplate;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::InvoiceTemplate - Invoice template table

=cut

__PACKAGE__->table('invoice_templates');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    name => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 0,
    },
    html_template => {
        data_type => 'longtext',
        is_nullable => 0,
    },
    is_default => {
        data_type => 'boolean',
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
__PACKAGE__->has_many(
    invoices => 'PropertyManager::Schema::Result::Invoice',
    'template_id'
);

1;
