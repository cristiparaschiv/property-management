package PropertyManager::Schema::Result::User;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

PropertyManager::Schema::Result::User - User authentication table

=cut

__PACKAGE__->table('users');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
        extra => { unsigned => 1 },
    },
    username => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 0,
    },
    password_hash => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    email => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    full_name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    id_card_series => {
        data_type => 'varchar',
        size => 10,
        is_nullable => 1,
    },
    id_card_number => {
        data_type => 'varchar',
        size => 20,
        is_nullable => 1,
    },
    id_card_issued_by => {
        data_type => 'varchar',
        size => 100,
        is_nullable => 1,
    },
    last_login => {
        data_type => 'datetime',
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
        default_value => \'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(username_unique => ['username']);
__PACKAGE__->add_unique_constraint(email_unique => ['email']);

# Helper method to serialize for API (remove password)
sub TO_JSON {
    my ($self) = @_;
    return {
        id => $self->id,
        username => $self->username,
        email => $self->email,
        full_name => $self->full_name,
        id_card_series => $self->id_card_series,
        id_card_number => $self->id_card_number,
        id_card_issued_by => $self->id_card_issued_by,
        last_login => $self->last_login ? "" . $self->last_login : undef,
        created_at => $self->created_at ? "" . $self->created_at : undef,
        updated_at => $self->updated_at ? "" . $self->updated_at : undef,
    };
}

1;
