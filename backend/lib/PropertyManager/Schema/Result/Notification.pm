package PropertyManager::Schema::Result::Notification;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::Notification - User notifications table

=cut

__PACKAGE__->table('notifications');

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
    type => {
        data_type => 'enum',
        extra => { list => [qw(warning info error success)] },
        is_nullable => 0,
        default_value => 'info',
    },
    category => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 0,
    },
    title => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    message => {
        data_type => 'text',
        is_nullable => 0,
    },
    entity_type => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 1,
    },
    entity_id => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    link => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    is_read => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    is_dismissed => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    expires_at => {
        data_type => 'timestamp',
        is_nullable => 1,
    },
    created_at => {
        data_type => 'timestamp',
        is_nullable => 0,
        default_value => \'CURRENT_TIMESTAMP',
    },
    read_at => {
        data_type => 'timestamp',
        is_nullable => 1,
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
