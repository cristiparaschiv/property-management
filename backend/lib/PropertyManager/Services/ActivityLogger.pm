package PropertyManager::Services::ActivityLogger;

use strict;
use warnings;
use JSON;
use Try::Tiny;

=head1 NAME

PropertyManager::Services::ActivityLogger - Service for logging system activities

=head1 SYNOPSIS

    use PropertyManager::Services::ActivityLogger;

    # Class method style (recommended for routes)
    PropertyManager::Services::ActivityLogger::log_create(
        $schema,
        'tenant',       # entity_type
        123,            # entity_id
        'John Doe',     # entity_name
        'Created new tenant: John Doe',  # description
        1,              # user_id (optional)
        '127.0.0.1',    # ip_address (optional)
    );

=cut

# Core logging function - class method style
sub _log {
    my ($schema, $action_type, $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata) = @_;

    my $metadata_json;
    if ($metadata && ref $metadata) {
        $metadata_json = encode_json($metadata);
    }

    try {
        $schema->resultset('ActivityLog')->create({
            user_id     => $user_id,
            action_type => $action_type || 'other',
            entity_type => $entity_type || 'system',
            entity_id   => $entity_id,
            entity_name => $entity_name,
            description => $description || '',
            metadata    => $metadata_json,
            ip_address  => $ip_address,
        });
    } catch {
        warn "Failed to log activity: $_";
    };
}

# Convenience class methods for common operations

sub log_create {
    my ($schema, $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata) = @_;
    _log($schema, 'create', $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata);
}

sub log_update {
    my ($schema, $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata) = @_;
    _log($schema, 'update', $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata);
}

sub log_delete {
    my ($schema, $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata) = @_;
    _log($schema, 'delete', $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata);
}

sub log_payment {
    my ($schema, $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata) = @_;
    _log($schema, 'payment', $entity_type, $entity_id, $entity_name, $description, $user_id, $ip_address, $metadata);
}

sub log_login {
    my ($schema, $user_id, $username, $ip_address) = @_;
    _log($schema, 'login', 'user', $user_id, $username, "Utilizator $username s-a autentificat", $user_id, $ip_address);
}

1;
