package PropertyManager::Schema::Result::TenantUtilityPercentage;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::TenantUtilityPercentage - Tenant utility percentage table

=cut

__PACKAGE__->table('tenant_utility_percentages');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
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
    percentage => {
        data_type => 'decimal',
        size => [5, 2],
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
__PACKAGE__->add_unique_constraint(tenant_utility_unique => ['tenant_id', 'utility_type']);

# Relationships
__PACKAGE__->belongs_to(
    tenant => 'PropertyManager::Schema::Result::Tenant',
    'tenant_id'
);

1;
