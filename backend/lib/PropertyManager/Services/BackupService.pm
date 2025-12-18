package PropertyManager::Services::BackupService;

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use File::Basename;
use DateTime;
use Try::Tiny;
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IPC::Run3 qw(run3);

=head1 NAME

PropertyManager::Services::BackupService - Database backup and restore service

=head1 SYNOPSIS

    use PropertyManager::Services::BackupService;

    my $backup = PropertyManager::Services::BackupService->new(
        schema => $schema,
        config => $config,
    );

    # Create a backup
    my $result = $backup->create_backup();
    # Returns: { file_path => '/tmp/...', file_name => 'backup_2024...', file_size => 12345 }

    # Restore from a backup file
    $backup->restore_backup('/path/to/backup.sql.gz');

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    die "config is required" unless $args{config};

    my $self = bless {
        schema => $args{schema},
        config => $args{config},
    }, $class;

    return $self;
}

=head2 _get_db_config

Get database configuration.

=cut

sub _get_db_config {
    my ($self) = @_;

    my $db = $self->{config}{database} || {};

    return {
        host     => $db->{host} || $ENV{DB_HOST} || 'localhost',
        port     => $db->{port} || $ENV{DB_PORT} || 3306,
        name     => $db->{name} || $ENV{DB_NAME} || 'property_management',
        user     => $db->{user} || $ENV{DB_USER} || 'root',
        password => $db->{password} || $ENV{DB_PASSWORD} || '',
    };
}

=head2 create_backup

Create a database backup.

Returns hashref with:
  - file_path: Full path to the backup file
  - file_name: Just the filename
  - file_size: Size in bytes

=cut

sub create_backup {
    my ($self, %args) = @_;

    my $db = $self->_get_db_config();

    # Create temp directory for backup
    my $temp_dir = $args{temp_dir} || tempdir(CLEANUP => 0);

    # Generate filename with timestamp
    my $timestamp = DateTime->now->strftime('%Y%m%d_%H%M%S');
    my $sql_file = File::Spec->catfile($temp_dir, "domistra_backup_$timestamp.sql");
    my $gz_file = "$sql_file.gz";

    # Build mysqldump command
    my @cmd = (
        'mysqldump',
        '--host=' . $db->{host},
        '--port=' . $db->{port},
        '--user=' . $db->{user},
        '--single-transaction',
        '--routines',
        '--triggers',
        '--add-drop-table',
        '--result-file=' . $sql_file,
    );

    # Add password if set
    if ($db->{password}) {
        push @cmd, '--password=' . $db->{password};
    }

    # Add database name
    push @cmd, $db->{name};

    # Execute mysqldump
    my $exit_code = system(@cmd);

    if ($exit_code != 0) {
        unlink $sql_file if -f $sql_file;
        die "mysqldump failed with exit code: " . ($exit_code >> 8);
    }

    unless (-f $sql_file && -s $sql_file) {
        die "mysqldump produced empty or missing file";
    }

    # Compress the backup
    gzip($sql_file => $gz_file)
        or die "Compression failed: $GzipError";

    # Remove uncompressed file
    unlink $sql_file;

    my $file_size = -s $gz_file;

    return {
        file_path => $gz_file,
        file_name => basename($gz_file),
        file_size => $file_size,
    };
}

=head2 restore_backup

Restore database from a backup file.
Uses IPC::Run3 to safely execute mysql command without shell interpolation.

=cut

sub restore_backup {
    my ($self, $backup_file) = @_;

    die "Backup file is required" unless $backup_file;
    die "Backup file does not exist: $backup_file" unless -f $backup_file;

    # Validate backup file path to prevent path traversal
    my $abs_path = File::Spec->rel2abs($backup_file);
    die "Invalid backup file path" unless $abs_path =~ m{^/tmp/} || $abs_path =~ m{^/var/};

    my $db = $self->_get_db_config();

    # Validate database config values to prevent injection
    for my $key (qw(host port user name)) {
        die "Invalid database $key" if $db->{$key} && $db->{$key} =~ /[;&|`\$]/;
    }

    # Determine if file is gzipped
    my $sql_file = $backup_file;
    my $is_gzipped = $backup_file =~ /\.gz$/i;

    if ($is_gzipped) {
        # Decompress to temp file
        my $temp_dir = tempdir(CLEANUP => 1);
        $sql_file = File::Spec->catfile($temp_dir, 'restore.sql');

        gunzip($backup_file => $sql_file)
            or die "Decompression failed: $GunzipError";
    }

    # Build mysql command as array (avoids shell interpolation)
    my @cmd = (
        'mysql',
        '--host=' . $db->{host},
        '--port=' . $db->{port},
        '--user=' . $db->{user},
        $db->{name},
    );

    # Add password if set (as separate argument to avoid shell issues)
    if ($db->{password}) {
        splice(@cmd, 4, 0, '--password=' . $db->{password});
    }

    # Read SQL file content for stdin
    my $sql_content;
    {
        local $/;
        open(my $fh, '<', $sql_file) or die "Cannot open $sql_file: $!";
        $sql_content = <$fh>;
        close($fh);
    }

    # Execute mysql using IPC::Run3 (avoids shell, passes SQL via stdin)
    my ($stdout, $stderr);
    eval {
        run3(\@cmd, \$sql_content, \$stdout, \$stderr);
    };

    if ($@ || $?) {
        my $error = $@ || $stderr || "Unknown error";
        die "mysql restore failed: $error";
    }

    return 1;
}

=head2 create_backup_record

Create a backup history record in the database.

=cut

sub create_backup_record {
    my ($self, %args) = @_;

    return $self->{schema}->resultset('BackupHistory')->create({
        file_name   => $args{file_name} || 'unknown',
        status      => $args{status} || 'pending',
        backup_type => $args{backup_type} || 'manual',
        created_by  => $args{user_id},
        started_at  => DateTime->now,
    });
}

=head2 update_backup_record

Update a backup history record.

=cut

sub update_backup_record {
    my ($self, $record, %args) = @_;

    my $update = {};

    $update->{status} = $args{status} if $args{status};
    $update->{file_name} = $args{file_name} if $args{file_name};
    $update->{drive_file_id} = $args{drive_file_id} if $args{drive_file_id};
    $update->{file_size} = $args{file_size} if $args{file_size};
    $update->{error_message} = $args{error_message} if exists $args{error_message};
    $update->{completed_at} = DateTime->now if $args{status} && ($args{status} eq 'completed' || $args{status} eq 'failed');

    $record->update($update) if %$update;

    return $record;
}

=head2 get_backup_history

Get backup history records.

=cut

sub get_backup_history {
    my ($self, %args) = @_;

    my $limit = $args{limit} || 20;
    my $offset = $args{offset} || 0;

    my @records = $self->{schema}->resultset('BackupHistory')->search({}, {
        order_by => { -desc => 'me.created_at' },
        rows     => $limit,
        offset   => $offset,
        prefetch => 'created_by_user',
    })->all;

    return \@records;
}

=head2 get_backup_by_id

Get a specific backup record.

=cut

sub get_backup_by_id {
    my ($self, $id) = @_;

    return $self->{schema}->resultset('BackupHistory')->find($id);
}

=head2 cleanup_temp_files

Remove temporary backup files.

=cut

sub cleanup_temp_files {
    my ($self, $file_path) = @_;

    if ($file_path && -f $file_path) {
        unlink $file_path;
    }
}

1;

__END__

=head1 DESCRIPTION

This service handles database backup and restore operations:
- Create mysqldump backups
- Compress backups with gzip
- Restore from backup files
- Track backup history in database

=head1 REQUIREMENTS

- mysqldump command must be available in PATH
- mysql command must be available in PATH (for restore)
- Write access to temp directory

=head1 CONFIGURATION

Database configuration from config.yml:

    database:
      host: localhost
      port: 3306
      name: property_management
      user: root
      password: secret

Or environment variables:
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

=cut
