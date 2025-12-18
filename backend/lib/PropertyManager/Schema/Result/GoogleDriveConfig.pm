package PropertyManager::Schema::Result::GoogleDriveConfig;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::GoogleDriveConfig - Google Drive OAuth configuration

=cut

__PACKAGE__->table('google_drive_config');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    access_token => {
        data_type => 'text',
        is_nullable => 1,
    },
    refresh_token => {
        data_type => 'text',
        is_nullable => 1,
    },
    token_expiry => {
        data_type => 'datetime',
        is_nullable => 1,
    },
    folder_id => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    folder_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    connected_email => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    connected_at => {
        data_type => 'timestamp',
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
        default_value => \'CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');

# Helper method to check if connected
sub is_connected {
    my $self = shift;
    return $self->access_token && $self->refresh_token ? 1 : 0;
}

# Helper method to check if token is expired
sub is_token_expired {
    my $self = shift;
    return 1 unless $self->token_expiry;

    my $expiry = $self->token_expiry;
    my $now = DateTime->now;

    return $expiry <= $now;
}

1;
