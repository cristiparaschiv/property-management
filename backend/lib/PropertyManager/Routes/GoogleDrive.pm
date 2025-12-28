package PropertyManager::Routes::GoogleDrive;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf get_current_user);
use PropertyManager::Services::GoogleDriveService;
use PropertyManager::Services::BackupService;
use PropertyManager::Services::ActivityLogger;
use Try::Tiny;
use URI::Escape qw(uri_escape);

prefix '/api/google';

# Initialize services
my ($drive_service, $backup_service);

hook 'before' => sub {
    $drive_service ||= PropertyManager::Services::GoogleDriveService->new(
        schema => schema,
        config => config,
    );
    $backup_service ||= PropertyManager::Services::BackupService->new(
        schema => schema,
        config => config,
    );
};

# ============================================================================
# OAuth Endpoints
# ============================================================================

=head2 GET /api/google/auth-url

Get the Google OAuth authorization URL.
User should be redirected to this URL to authorize the app.

=cut

get '/auth-url' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    try {
        my $url = $drive_service->get_auth_url();
        return { success => 1, data => { url => $url } };
    } catch {
        status 500;
        return { success => 0, error => "Failed to generate auth URL: $_" };
    };
};

=head2 GET /api/google/callback

OAuth callback endpoint. Google redirects here after user authorizes.
Exchanges the code for tokens and redirects to frontend.

=cut

get '/callback' => sub {
    my $code = query_parameters->get('code');
    my $error = query_parameters->get('error');

    my $frontend_url = config->{frontend_url} || 'http://localhost:5173';

    if ($error) {
        return redirect "$frontend_url/settings?google=error&message=" . uri_escape($error);
    }

    unless ($code) {
        return redirect "$frontend_url/settings?google=error&message=No%20authorization%20code";
    }

    try {
        my $result = $drive_service->exchange_code($code);

        # Log the connection
        PropertyManager::Services::ActivityLogger::log_create(
            schema,
            'google_drive',
            undef,
            $result->{email},
            "Google Drive conectat: $result->{email}",
            undef,
            request->address,
        );

        return redirect "$frontend_url/settings?google=connected";
    } catch {
        my $error_msg = $_;
        $error_msg =~ s/\s+/ /g;
        return redirect "$frontend_url/settings?google=error&message=" . uri_escape($error_msg);
    };
};

=head2 GET /api/google/status

Get the current Google Drive connection status.

=cut

get '/status' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    try {
        my $status = $drive_service->get_status();
        return { success => 1, data => $status };
    } catch {
        status 500;
        return { success => 0, error => "Failed to get status: $_" };
    };
};

=head2 POST /api/google/disconnect

Disconnect from Google Drive.

=cut

post '/disconnect' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = get_current_user();

    try {
        $drive_service->disconnect();

        PropertyManager::Services::ActivityLogger::log_delete(
            schema,
            'google_drive',
            undef,
            'Google Drive',
            "Google Drive deconectat",
            $user->{id},
            request->address,
        );

        return { success => 1, message => 'Disconnected from Google Drive' };
    } catch {
        status 500;
        return { success => 0, error => "Failed to disconnect: $_" };
    };
};

# ============================================================================
# Backup Endpoints
# ============================================================================

=head2 POST /api/google/backup

Trigger a new backup and upload to Google Drive.

=cut

post '/backup' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = get_current_user();

    # Check if connected
    my $status = $drive_service->get_status();
    unless ($status->{connected}) {
        status 400;
        return { success => 0, error => 'Google Drive not connected' };
    }

    # Create backup record
    my $record = $backup_service->create_backup_record(
        file_name   => 'Creating...',
        status      => 'creating',
        backup_type => 'manual',
        user_id     => $user->{id},
    );

    try {
        # Create database backup
        $backup_service->update_backup_record($record, status => 'creating');
        my $backup = $backup_service->create_backup();

        # Update record with file info
        $backup_service->update_backup_record($record,
            file_name => $backup->{file_name},
            file_size => $backup->{file_size},
            status    => 'uploading',
        );

        # Upload to Google Drive
        my $upload_result = $drive_service->upload_file($backup->{file_path});

        # Update record with Drive info
        $backup_service->update_backup_record($record,
            drive_file_id => $upload_result->{file_id},
            status        => 'completed',
        );

        # Cleanup temp file
        $backup_service->cleanup_temp_files($backup->{file_path});

        # Log activity
        PropertyManager::Services::ActivityLogger::log_create(
            schema,
            'backup',
            $record->id,
            $backup->{file_name},
            "Backup creat și încărcat în Google Drive",
            $user->{id},
            request->address,
            { file_size => $backup->{file_size} },
        );

        return {
            success => 1,
            data => {
                id            => $record->id,
                file_name     => $backup->{file_name},
                file_size     => $backup->{file_size},
                drive_file_id => $upload_result->{file_id},
                status        => 'completed',
            },
        };
    } catch {
        my $error = $_;
        $backup_service->update_backup_record($record,
            status        => 'failed',
            error_message => $error,
        );
        status 500;
        return { success => 0, error => "Backup failed: $error" };
    };
};

=head2 GET /api/google/backups

List all backups (from database history).

=cut

get '/backups' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $limit = query_parameters->get('limit') || 20;
    my $offset = query_parameters->get('offset') || 0;

    # Cleanup any stuck backups before listing
    $backup_service->cleanup_stuck_backups(timeout_minutes => 30);

    my $records = $backup_service->get_backup_history(
        limit  => $limit,
        offset => $offset,
    );

    my @data = map {
        {
            id            => $_->id,
            file_name     => $_->file_name,
            drive_file_id => $_->drive_file_id,
            file_size     => $_->file_size,
            status        => $_->status,
            error_message => $_->error_message,
            backup_type   => $_->backup_type,
            created_by    => $_->created_by_user ? $_->created_by_user->full_name : undef,
            started_at    => $_->started_at ? $_->started_at . '' : undef,
            completed_at  => $_->completed_at ? $_->completed_at . '' : undef,
            created_at    => $_->created_at . '',
        }
    } @$records;

    return { success => 1, data => \@data };
};

=head2 GET /api/google/backups/drive

List backups directly from Google Drive.

=cut

get '/backups/drive' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    try {
        my $files = $drive_service->list_files();
        return { success => 1, data => $files };
    } catch {
        status 500;
        return { success => 0, error => "Failed to list Drive files: $_" };
    };
};

=head2 POST /api/google/restore/:id

Restore from a backup.

=cut

post '/restore/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = get_current_user();
    my $id = route_parameters->get('id');

    # Get backup record
    my $record = $backup_service->get_backup_by_id($id);
    unless ($record) {
        status 404;
        return { success => 0, error => 'Backup not found' };
    }

    unless ($record->drive_file_id) {
        status 400;
        return { success => 0, error => 'Backup file not available in Google Drive' };
    }

    try {
        # Download from Google Drive
        my $temp_dir = File::Temp::tempdir(CLEANUP => 1);
        my $download_path = File::Spec->catfile($temp_dir, $record->file_name);

        $drive_service->download_file($record->drive_file_id, $download_path);

        # Restore the backup
        $backup_service->restore_backup($download_path);

        # Log activity
        PropertyManager::Services::ActivityLogger::log_update(
            schema,
            'backup',
            $record->id,
            $record->file_name,
            "Baza de date restaurată din backup: " . $record->file_name,
            $user->{id},
            request->address,
        );

        return { success => 1, message => 'Database restored successfully' };
    } catch {
        status 500;
        return { success => 0, error => "Restore failed: $_" };
    };
};

=head2 DELETE /api/google/backups/:id

Delete a backup from history (optionally from Drive too).

=cut

del '/backups/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = get_current_user();
    my $id = route_parameters->get('id');
    my $delete_from_drive = query_parameters->get('delete_from_drive');

    my $record = $backup_service->get_backup_by_id($id);
    unless ($record) {
        status 404;
        return { success => 0, error => 'Backup not found' };
    }

    try {
        # Delete from Drive if requested
        if ($delete_from_drive && $record->drive_file_id) {
            $drive_service->delete_file($record->drive_file_id);
        }

        my $file_name = $record->file_name;

        # Delete record from database
        $record->delete;

        # Log activity
        PropertyManager::Services::ActivityLogger::log_delete(
            schema,
            'backup',
            $id,
            $file_name,
            "Backup șters: $file_name",
            $user->{id},
            request->address,
        );

        return { success => 1, message => 'Backup deleted' };
    } catch {
        status 500;
        return { success => 0, error => "Failed to delete backup: $_" };
    };
};

1;

__END__

=head1 NAME

PropertyManager::Routes::GoogleDrive - Google Drive backup integration routes

=head1 DESCRIPTION

Provides API endpoints for:
- Google OAuth authorization flow
- Backup creation and upload
- Backup listing and management
- Database restore from backup

=head1 ENDPOINTS

=over 4

=item GET /api/google/auth-url

Get OAuth authorization URL.

=item GET /api/google/callback

OAuth callback (exchanges code for tokens).

=item GET /api/google/status

Get connection status.

=item POST /api/google/disconnect

Disconnect from Google Drive.

=item POST /api/google/backup

Create and upload a new backup.

=item GET /api/google/backups

List backup history.

=item POST /api/google/restore/:id

Restore from a specific backup.

=item DELETE /api/google/backups/:id

Delete a backup.

=back

=cut
