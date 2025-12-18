package PropertyManager::Schema::Result::LoginAttempt;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::LoginAttempt - Login attempts for rate limiting

=cut

__PACKAGE__->table('login_attempts');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    ip_address => {
        data_type => 'varchar',
        size => 45,
        is_nullable => 0,
    },
    username => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    is_successful => {
        data_type => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    created_at => {
        data_type => 'datetime',
        is_nullable => 1,
        set_on_create => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);

1;

__END__

=head1 DESCRIPTION

This table stores login attempts for brute force protection via rate limiting.
Failed attempts are counted per IP address within a time window.

=head1 COLUMNS

=over 4

=item id - Auto-increment primary key

=item ip_address - Client IP address (IPv4 or IPv6)

=item username - Username attempted (for auditing)

=item is_successful - Whether login succeeded

=item created_at - Timestamp of the attempt

=back

=cut
