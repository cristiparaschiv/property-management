#!/usr/bin/env perl

=head1 NAME

restore_from_drive.pl - Restore database from Google Drive backup

=head1 SYNOPSIS

    # List available backups
    ./restore_from_drive.pl --list

    # Restore from a specific backup ID (from database history)
    ./restore_from_drive.pl --backup-id 5

    # Restore from a Google Drive file ID directly
    ./restore_from_drive.pl --drive-id 1abc123def456

    # Restore from a local file
    ./restore_from_drive.pl --file /path/to/backup.sql.gz

=head1 DESCRIPTION

This script allows database restoration from:
- Backups tracked in the backup_history table
- Files stored directly in Google Drive
- Local backup files

=cut

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Getopt::Long;
use Pod::Usage;
use Term::ANSIColor;
use YAML::XS qw(LoadFile);
use File::Temp qw(tempdir);
use File::Spec;

use PropertyManager::Schema;
use PropertyManager::Services::GoogleDriveService;
use PropertyManager::Services::BackupService;

# Parse command line options
my $help = 0;
my $list = 0;
my $backup_id;
my $drive_id;
my $local_file;
my $force = 0;

GetOptions(
    'help|h'      => \$help,
    'list|l'      => \$list,
    'backup-id=i' => \$backup_id,
    'drive-id=s'  => \$drive_id,
    'file=s'      => \$local_file,
    'force|f'     => \$force,
) or pod2usage(2);

pod2usage(1) if $help;

# Load configuration
my $config_file = "$Bin/../config.yml";
my $config = LoadFile($config_file);

# Initialize database connection
my $dsn = sprintf(
    "dbi:mysql:database=%s;host=%s;port=%s",
    $config->{database}{name} || $ENV{DB_NAME} || 'property_management',
    $config->{database}{host} || $ENV{DB_HOST} || 'localhost',
    $config->{database}{port} || $ENV{DB_PORT} || 3306,
);

my $schema = PropertyManager::Schema->connect(
    $dsn,
    $config->{database}{user} || $ENV{DB_USER} || 'root',
    $config->{database}{password} || $ENV{DB_PASSWORD} || '',
    { mysql_enable_utf8mb4 => 1 },
);

# Initialize services
my $drive_service = PropertyManager::Services::GoogleDriveService->new(
    schema => $schema,
    config => $config,
);

my $backup_service = PropertyManager::Services::BackupService->new(
    schema => $schema,
    config => $config,
);

# Handle --list option
if ($list) {
    list_backups();
    exit 0;
}

# Validate input
unless ($backup_id || $drive_id || $local_file) {
    print colored("Error: ", 'red'), "Please specify one of: --backup-id, --drive-id, or --file\n";
    pod2usage(2);
}

# Perform restoration
if ($backup_id) {
    restore_from_backup_id($backup_id);
} elsif ($drive_id) {
    restore_from_drive_id($drive_id);
} elsif ($local_file) {
    restore_from_file($local_file);
}

# ============================================================================
# SUBROUTINES
# ============================================================================

sub list_backups {
    print colored("\n=== Backup History ===\n\n", 'bold');

    my $records = $backup_service->get_backup_history(limit => 20);

    if (@$records == 0) {
        print "No backups found in history.\n\n";
        return;
    }

    printf "%-4s %-40s %-12s %-10s %-20s\n",
        "ID", "File Name", "Size", "Status", "Created At";
    print "-" x 90, "\n";

    for my $record (@$records) {
        my $size = $record->file_size
            ? sprintf("%.2f MB", $record->file_size / 1024 / 1024)
            : "-";

        my $status_color = $record->status eq 'completed' ? 'green'
                         : $record->status eq 'failed' ? 'red'
                         : 'yellow';

        printf "%-4d %-40s %-12s ",
            $record->id,
            substr($record->file_name, 0, 40),
            $size;

        print colored(sprintf("%-10s", $record->status), $status_color);
        print " ";
        printf "%-20s\n", $record->created_at;
    }

    print "\n";

    # Check Google Drive connection
    my $status = $drive_service->get_status();
    if ($status->{connected}) {
        print colored("Google Drive: ", 'green'), "Connected ($status->{email})\n";
    } else {
        print colored("Google Drive: ", 'yellow'), "Not connected\n";
    }
    print "\n";
}

sub restore_from_backup_id {
    my ($id) = @_;

    my $record = $backup_service->get_backup_by_id($id);

    unless ($record) {
        print colored("Error: ", 'red'), "Backup with ID $id not found\n";
        exit 1;
    }

    unless ($record->drive_file_id) {
        print colored("Error: ", 'red'), "Backup $id does not have a Google Drive file ID\n";
        exit 1;
    }

    print colored("\n=== Restore from Backup #$id ===\n\n", 'bold');
    print "File Name:  $record->{file_name}\n";
    print "Created At: $record->{created_at}\n";
    print "Status:     $record->{status}\n";
    print "Drive ID:   $record->{drive_file_id}\n\n";

    confirm_restore() unless $force;

    restore_from_drive_id($record->drive_file_id, $record->file_name);
}

sub restore_from_drive_id {
    my ($file_id, $filename) = @_;

    $filename ||= "backup_download.sql.gz";

    print colored("Downloading from Google Drive...\n", 'cyan');

    my $temp_dir = tempdir(CLEANUP => 1);
    my $download_path = File::Spec->catfile($temp_dir, $filename);

    eval {
        $drive_service->download_file($file_id, $download_path);
    };

    if ($@) {
        print colored("Error: ", 'red'), "Failed to download: $@\n";
        exit 1;
    }

    print colored("Download complete: ", 'green'), "$download_path\n\n";

    restore_from_file($download_path);
}

sub restore_from_file {
    my ($file_path) = @_;

    unless (-f $file_path) {
        print colored("Error: ", 'red'), "File not found: $file_path\n";
        exit 1;
    }

    my $size = -s $file_path;
    print colored("\n=== Restore from Local File ===\n\n", 'bold') unless $backup_id || $drive_id;
    print "File:  $file_path\n";
    print "Size:  ", sprintf("%.2f MB", $size / 1024 / 1024), "\n\n";

    confirm_restore() unless $force;

    print colored("Restoring database...\n", 'cyan');

    eval {
        $backup_service->restore_backup($file_path);
    };

    if ($@) {
        print colored("Error: ", 'red'), "Restore failed: $@\n";
        exit 1;
    }

    print colored("\n✓ Database restored successfully!\n\n", 'green bold');
}

sub confirm_restore {
    print colored("WARNING: ", 'yellow bold');
    print "This will OVERWRITE the current database!\n";
    print "All data added after this backup will be LOST.\n\n";
    print "Type 'RESTORE' to confirm: ";

    my $input = <STDIN>;
    chomp $input;

    unless ($input eq 'RESTORE') {
        print colored("\nRestore cancelled.\n\n", 'yellow');
        exit 0;
    }

    print "\n";
}

__END__

=head1 OPTIONS

=over 4

=item B<--list, -l>

List available backups from the backup history.

=item B<--backup-id ID>

Restore from a specific backup ID (from backup_history table).

=item B<--drive-id ID>

Restore from a Google Drive file ID directly.

=item B<--file PATH>

Restore from a local backup file.

=item B<--force, -f>

Skip confirmation prompt (use with caution!).

=item B<--help, -h>

Show this help message.

=back

=head1 EXAMPLES

    # List all available backups
    ./restore_from_drive.pl --list

    # Restore backup #5 from history
    ./restore_from_drive.pl --backup-id 5

    # Restore with force (no confirmation)
    ./restore_from_drive.pl --backup-id 5 --force

    # Restore from a specific Google Drive file
    ./restore_from_drive.pl --drive-id 1abc123def456

    # Restore from a local file
    ./restore_from_drive.pl --file /backups/domistra_backup_20240115.sql.gz

=cut
