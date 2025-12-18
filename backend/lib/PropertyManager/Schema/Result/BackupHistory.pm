package PropertyManager::Schema::Result::BackupHistory;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::BackupHistory - Backup history tracking

=cut

__PACKAGE__->table('backup_history');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    file_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    drive_file_id => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    file_size => {
        data_type => 'bigint',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    status => {
        data_type => 'enum',
        extra => { list => [qw(pending creating uploading completed failed)] },
        is_nullable => 0,
        default_value => 'pending',
    },
    error_message => {
        data_type => 'text',
        is_nullable => 1,
    },
    backup_type => {
        data_type => 'enum',
        extra => { list => [qw(manual scheduled)] },
        is_nullable => 0,
        default_value => 'manual',
    },
    created_by => {
        data_type => 'integer',
        is_nullable => 1,
        extra => { unsigned => 1 },
    },
    started_at => {
        data_type => 'timestamp',
        is_nullable => 1,
    },
    completed_at => {
        data_type => 'timestamp',
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
    created_by_user => 'PropertyManager::Schema::Result::User',
    'created_by',
    { join_type => 'LEFT' }
);

1;
