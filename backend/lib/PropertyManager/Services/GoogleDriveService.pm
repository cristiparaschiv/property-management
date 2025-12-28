package PropertyManager::Services::GoogleDriveService;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
use JSON;
use URI::Escape;
use Try::Tiny;
use DateTime;
use File::Basename;

=head1 NAME

PropertyManager::Services::GoogleDriveService - Google Drive API integration

=head1 SYNOPSIS

    use PropertyManager::Services::GoogleDriveService;

    my $drive = PropertyManager::Services::GoogleDriveService->new(
        schema => $schema,
        config => $config,
    );

    # Get OAuth authorization URL
    my $auth_url = $drive->get_auth_url();

    # Exchange authorization code for tokens
    $drive->exchange_code($code);

    # Upload a file
    $drive->upload_file('/path/to/backup.sql.gz');

=cut

# Google OAuth endpoints
use constant {
    GOOGLE_AUTH_URL    => 'https://accounts.google.com/o/oauth2/v2/auth',
    GOOGLE_TOKEN_URL   => 'https://oauth2.googleapis.com/token',
    GOOGLE_USERINFO_URL => 'https://www.googleapis.com/oauth2/v2/userinfo',
    GOOGLE_DRIVE_URL   => 'https://www.googleapis.com/drive/v3',
    GOOGLE_UPLOAD_URL  => 'https://www.googleapis.com/upload/drive/v3/files',
};

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    die "config is required" unless $args{config};

    my $self = bless {
        schema => $args{schema},
        config => $args{config},
        ua     => LWP::UserAgent->new(timeout => 60),
    }, $class;

    return $self;
}

=head2 get_google_config

Get Google OAuth configuration from config file.

=cut

sub get_google_config {
    my ($self) = @_;

    my $google = $self->{config}{google} || {};

    return {
        client_id     => $google->{client_id} || $ENV{GOOGLE_CLIENT_ID},
        client_secret => $google->{client_secret} || $ENV{GOOGLE_CLIENT_SECRET},
        redirect_uri  => $google->{redirect_uri} || $ENV{GOOGLE_REDIRECT_URI},
    };
}

=head2 get_auth_url

Generate Google OAuth authorization URL.

=cut

sub get_auth_url {
    my ($self) = @_;

    my $google = $self->get_google_config();

    die "Google client_id not configured" unless $google->{client_id};
    die "Google redirect_uri not configured" unless $google->{redirect_uri};

    my $scope = 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email';

    my $params = {
        client_id     => $google->{client_id},
        redirect_uri  => $google->{redirect_uri},
        response_type => 'code',
        scope         => $scope,
        access_type   => 'offline',
        prompt        => 'consent',  # Force consent to get refresh token
    };

    my @pairs = map { uri_escape($_) . '=' . uri_escape($params->{$_}) } keys %$params;
    my $query_string = join('&', @pairs);

    return GOOGLE_AUTH_URL . '?' . $query_string;
}

=head2 exchange_code

Exchange authorization code for access and refresh tokens.

=cut

sub exchange_code {
    my ($self, $code) = @_;

    die "Authorization code is required" unless $code;

    my $google = $self->get_google_config();

    die "Google client_id not configured" unless $google->{client_id};
    die "Google client_secret not configured" unless $google->{client_secret};
    die "Google redirect_uri not configured" unless $google->{redirect_uri};

    my $response = $self->{ua}->post(GOOGLE_TOKEN_URL, {
        code          => $code,
        client_id     => $google->{client_id},
        client_secret => $google->{client_secret},
        redirect_uri  => $google->{redirect_uri},
        grant_type    => 'authorization_code',
    });

    unless ($response->is_success) {
        my $error = try { decode_json($response->content) } || {};
        die "Failed to exchange code: " . ($error->{error_description} || $response->status_line);
    }

    my $data = decode_json($response->content);

    # Get user info
    my $user_info = $self->_get_user_info($data->{access_token});

    # Calculate token expiry
    my $expiry = DateTime->now->add(seconds => $data->{expires_in} || 3600);

    # Save tokens to database
    my $config = $self->_get_config();
    $config->update({
        access_token    => $data->{access_token},
        refresh_token   => $data->{refresh_token},
        token_expiry    => $expiry->datetime(' '),
        connected_email => $user_info->{email},
        connected_at    => DateTime->now->datetime(' '),
    });

    # Create or get the backup folder
    $self->_ensure_backup_folder($data->{access_token});

    return {
        email => $user_info->{email},
    };
}

=head2 _get_user_info

Get user info from Google API.

=cut

sub _get_user_info {
    my ($self, $access_token) = @_;

    my $request = HTTP::Request->new(GET => GOOGLE_USERINFO_URL);
    $request->header('Authorization' => "Bearer $access_token");

    my $response = $self->{ua}->request($request);

    unless ($response->is_success) {
        die "Failed to get user info: " . $response->status_line;
    }

    return decode_json($response->content);
}

=head2 _get_config

Get or create Google Drive configuration from database.

=cut

sub _get_config {
    my ($self) = @_;

    my $config = $self->{schema}->resultset('GoogleDriveConfig')->find(1);

    unless ($config) {
        $config = $self->{schema}->resultset('GoogleDriveConfig')->create({ id => 1 });
    }

    return $config;
}

=head2 get_status

Get current connection status.

=cut

sub get_status {
    my ($self) = @_;

    my $config = $self->_get_config();

    # Determine if we need reconnection (had a connection but token was invalidated)
    my $needs_reconnect = 0;
    if (!$config->access_token && $config->connected_email) {
        $needs_reconnect = 1;
    }

    return {
        connected        => $config->is_connected ? 1 : 0,
        needs_reconnect  => $needs_reconnect,
        email            => $config->connected_email,
        folder_name      => $config->folder_name,
        connected_at     => $config->connected_at ? $config->connected_at . '' : undef,
    };
}

=head2 disconnect

Disconnect from Google Drive (remove tokens).

=cut

sub disconnect {
    my ($self) = @_;

    my $config = $self->_get_config();

    $config->update({
        access_token    => undef,
        refresh_token   => undef,
        token_expiry    => undef,
        folder_id       => undef,
        folder_name     => undef,
        connected_email => undef,
        connected_at    => undef,
    });

    return 1;
}

=head2 _refresh_token_if_needed

Refresh access token if expired.

=cut

sub _refresh_token_if_needed {
    my ($self) = @_;

    my $config = $self->_get_config();

    die "Not connected to Google Drive" unless $config->is_connected;

    # Check if token is expired (with 5 minute buffer)
    my $expiry = $config->token_expiry;
    if ($expiry) {
        # Convert expiry to comparable format (MySQL datetime is already sortable as string)
        my $expiry_str = "$expiry";
        $expiry_str =~ s/T/ /;  # Handle ISO format if present

        # Get current time + 5 min buffer in MySQL format
        my $buffer = DateTime->now->add(minutes => 5)->strftime('%Y-%m-%d %H:%M:%S');

        # String comparison works for MySQL datetime format
        return $config->access_token if $expiry_str gt $buffer;
    }

    # Refresh the token
    my $google = $self->get_google_config();

    my $response = $self->{ua}->post(GOOGLE_TOKEN_URL, {
        refresh_token => $config->refresh_token,
        client_id     => $google->{client_id},
        client_secret => $google->{client_secret},
        grant_type    => 'refresh_token',
    });

    unless ($response->is_success) {
        my $error = try { decode_json($response->content) } || {};
        my $error_code = $error->{error} || '';
        my $error_desc = $error->{error_description} || $response->status_line;

        # Check if token is expired or revoked - mark connection as invalid
        if ($error_code eq 'invalid_grant' || $error_desc =~ /expired|revoked/i) {
            # Mark connection as needing re-authentication
            $config->update({
                access_token => undef,
                token_expiry => undef,
                # Keep refresh_token and other info for diagnostic purposes
            });
            die "Google Drive session expired. Please reconnect to Google Drive.";
        }

        die "Failed to refresh token: $error_desc";
    }

    my $data = decode_json($response->content);

    # Calculate new expiry
    my $new_expiry = DateTime->now->add(seconds => $data->{expires_in} || 3600);

    # Update tokens - also update refresh_token if Google provided a new one
    my $update_data = {
        access_token => $data->{access_token},
        token_expiry => $new_expiry->datetime(' '),
    };

    # Google may provide a new refresh token (rotation)
    if ($data->{refresh_token}) {
        $update_data->{refresh_token} = $data->{refresh_token};
    }

    $config->update($update_data);

    return $data->{access_token};
}

=head2 _ensure_backup_folder

Create the "Domistra Backups" folder if it doesn't exist.

=cut

sub _ensure_backup_folder {
    my ($self, $access_token) = @_;

    my $config = $self->_get_config();

    # If we already have a folder, verify it still exists
    if ($config->folder_id) {
        my $folder = $self->_get_file_metadata($access_token, $config->folder_id);
        return if $folder && !$folder->{trashed};
    }

    # Search for existing folder
    my $folder_name = 'Domistra Backups';
    my $query = "name='$folder_name' and mimeType='application/vnd.google-apps.folder' and trashed=false";

    my $url = GOOGLE_DRIVE_URL . '/files?q=' . uri_escape($query) . '&fields=files(id,name)';

    my $request = HTTP::Request->new(GET => $url);
    $request->header('Authorization' => "Bearer $access_token");

    my $response = $self->{ua}->request($request);

    if ($response->is_success) {
        my $data = decode_json($response->content);
        if ($data->{files} && @{$data->{files}} > 0) {
            my $folder = $data->{files}[0];
            $config->update({
                folder_id   => $folder->{id},
                folder_name => $folder->{name},
            });
            return;
        }
    }

    # Create new folder
    my $metadata = encode_json({
        name     => $folder_name,
        mimeType => 'application/vnd.google-apps.folder',
    });

    my $create_request = HTTP::Request->new(POST => GOOGLE_DRIVE_URL . '/files');
    $create_request->header('Authorization' => "Bearer $access_token");
    $create_request->header('Content-Type' => 'application/json');
    $create_request->content($metadata);

    my $create_response = $self->{ua}->request($create_request);

    unless ($create_response->is_success) {
        die "Failed to create backup folder: " . $create_response->status_line;
    }

    my $folder_data = decode_json($create_response->content);

    $config->update({
        folder_id   => $folder_data->{id},
        folder_name => $folder_name,
    });
}

=head2 _get_file_metadata

Get file metadata from Google Drive.

=cut

sub _get_file_metadata {
    my ($self, $access_token, $file_id) = @_;

    my $url = GOOGLE_DRIVE_URL . "/files/$file_id?fields=id,name,trashed";

    my $request = HTTP::Request->new(GET => $url);
    $request->header('Authorization' => "Bearer $access_token");

    my $response = $self->{ua}->request($request);

    return undef unless $response->is_success;

    return decode_json($response->content);
}

=head2 upload_file

Upload a file to Google Drive backup folder.

=cut

sub upload_file {
    my ($self, $filepath) = @_;

    die "File path is required" unless $filepath;
    die "File does not exist: $filepath" unless -f $filepath;

    my $access_token = $self->_refresh_token_if_needed();
    my $config = $self->_get_config();

    die "Backup folder not configured" unless $config->folder_id;

    my $filename = basename($filepath);
    my $file_size = -s $filepath;

    # Read file content
    open my $fh, '<:raw', $filepath or die "Cannot open file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Create multipart upload
    my $metadata = encode_json({
        name    => $filename,
        parents => [$config->folder_id],
    });

    # Use resumable upload for larger files (> 5MB)
    if ($file_size > 5 * 1024 * 1024) {
        return $self->_resumable_upload($access_token, $filepath, $filename, $config->folder_id);
    }

    # Simple multipart upload
    my $boundary = 'domistra_backup_boundary_' . time();

    my $body = "--$boundary\r\n";
    $body .= "Content-Type: application/json; charset=UTF-8\r\n\r\n";
    $body .= $metadata . "\r\n";
    $body .= "--$boundary\r\n";
    $body .= "Content-Type: application/gzip\r\n\r\n";
    $body .= $content . "\r\n";
    $body .= "--$boundary--";

    my $url = GOOGLE_UPLOAD_URL . '?uploadType=multipart&fields=id,name,size';

    my $request = HTTP::Request->new(POST => $url);
    $request->header('Authorization' => "Bearer $access_token");
    $request->header('Content-Type' => "multipart/related; boundary=$boundary");
    $request->header('Content-Length' => length($body));
    $request->content($body);

    my $response = $self->{ua}->request($request);

    unless ($response->is_success) {
        my $error = try { decode_json($response->content) } || {};
        die "Failed to upload file: " . ($error->{error}{message} || $response->status_line);
    }

    my $result = decode_json($response->content);

    return {
        file_id   => $result->{id},
        file_name => $result->{name},
        file_size => $result->{size},
    };
}

=head2 _resumable_upload

Resumable upload for larger files.

=cut

sub _resumable_upload {
    my ($self, $access_token, $filepath, $filename, $folder_id) = @_;

    my $file_size = -s $filepath;

    # Initiate resumable upload
    my $metadata = encode_json({
        name    => $filename,
        parents => [$folder_id],
    });

    my $init_url = GOOGLE_UPLOAD_URL . '?uploadType=resumable';

    my $init_request = HTTP::Request->new(POST => $init_url);
    $init_request->header('Authorization' => "Bearer $access_token");
    $init_request->header('Content-Type' => 'application/json; charset=UTF-8');
    $init_request->header('X-Upload-Content-Type' => 'application/gzip');
    $init_request->header('X-Upload-Content-Length' => $file_size);
    $init_request->content($metadata);

    my $init_response = $self->{ua}->request($init_request);

    unless ($init_response->is_success) {
        die "Failed to initiate upload: " . $init_response->status_line;
    }

    my $upload_url = $init_response->header('Location');
    die "No upload URL returned" unless $upload_url;

    # Upload the file content
    open my $fh, '<:raw', $filepath or die "Cannot open file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $upload_request = HTTP::Request->new(PUT => $upload_url);
    $upload_request->header('Content-Type' => 'application/gzip');
    $upload_request->header('Content-Length' => $file_size);
    $upload_request->content($content);

    my $upload_response = $self->{ua}->request($upload_request);

    unless ($upload_response->is_success) {
        die "Failed to upload file content: " . $upload_response->status_line;
    }

    my $result = decode_json($upload_response->content);

    return {
        file_id   => $result->{id},
        file_name => $result->{name},
        file_size => $result->{size},
    };
}

=head2 list_files

List backup files in the backup folder.

=cut

sub list_files {
    my ($self) = @_;

    my $access_token = $self->_refresh_token_if_needed();
    my $config = $self->_get_config();

    return [] unless $config->folder_id;

    my $query = "'$config->{folder_id}' in parents and trashed=false";
    my $fields = 'files(id,name,size,createdTime,modifiedTime)';

    my $url = GOOGLE_DRIVE_URL . '/files?q=' . uri_escape($query)
            . '&fields=' . uri_escape($fields)
            . '&orderBy=createdTime%20desc'
            . '&pageSize=50';

    my $request = HTTP::Request->new(GET => $url);
    $request->header('Authorization' => "Bearer $access_token");

    my $response = $self->{ua}->request($request);

    unless ($response->is_success) {
        die "Failed to list files: " . $response->status_line;
    }

    my $data = decode_json($response->content);

    return $data->{files} || [];
}

=head2 download_file

Download a file from Google Drive.

=cut

sub download_file {
    my ($self, $file_id, $destination) = @_;

    die "File ID is required" unless $file_id;
    die "Destination path is required" unless $destination;

    my $access_token = $self->_refresh_token_if_needed();

    my $url = GOOGLE_DRIVE_URL . "/files/$file_id?alt=media";

    my $request = HTTP::Request->new(GET => $url);
    $request->header('Authorization' => "Bearer $access_token");

    my $response = $self->{ua}->request($request);

    unless ($response->is_success) {
        die "Failed to download file: " . $response->status_line;
    }

    open my $fh, '>:raw', $destination or die "Cannot write to file: $!";
    print $fh $response->content;
    close $fh;

    return $destination;
}

=head2 delete_file

Delete a file from Google Drive.

=cut

sub delete_file {
    my ($self, $file_id) = @_;

    die "File ID is required" unless $file_id;

    my $access_token = $self->_refresh_token_if_needed();

    my $url = GOOGLE_DRIVE_URL . "/files/$file_id";

    my $request = HTTP::Request->new(DELETE => $url);
    $request->header('Authorization' => "Bearer $access_token");

    my $response = $self->{ua}->request($request);

    # 204 No Content is success for delete
    unless ($response->is_success || $response->code == 204) {
        die "Failed to delete file: " . $response->status_line;
    }

    return 1;
}

1;

__END__

=head1 DESCRIPTION

This service handles Google Drive integration for backup storage:
- OAuth 2.0 authorization flow
- Token management (access + refresh)
- File upload/download/list/delete
- Automatic backup folder creation

=head1 CONFIGURATION

Requires the following configuration in config.yml or environment variables:

    google:
      client_id: "your-client-id.apps.googleusercontent.com"
      client_secret: "your-client-secret"
      redirect_uri: "http://localhost:5001/api/google/callback"

Or set environment variables:
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET
    GOOGLE_REDIRECT_URI

=cut
