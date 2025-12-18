package PropertyManager::Schema::Result::ActivityLog;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::ActivityLog - Activity log tracking table

=cut

__PACKAGE__->table('activity_logs');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    user_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    action_type => {
        data_type => 'enum',
        extra => { list => [qw(create update delete payment login other)] },
        is_nullable => 0,
    },
    entity_type => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 0,
    },
    entity_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    entity_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    description => {
        data_type => 'text',
        is_nullable => 0,
    },
    metadata => {
        data_type => 'text',
        is_nullable => 1,
    },
    ip_address => {
        data_type => 'varchar',
        size => 45,
        is_nullable => 1,
    },
    created_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');

# Relationships
__PACKAGE__->belongs_to(
    user => 'PropertyManager::Schema::Result::User',
    'user_id',
    { join_type => 'LEFT' }
);

1;
