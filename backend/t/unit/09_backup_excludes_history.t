#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../lib";
use TestHelper;
use PropertyManager::App;
use PropertyManager::Services::BackupService;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

my $svc = PropertyManager::Services::BackupService->new(
    schema => TestHelper::schema(),
    config => PropertyManager::App->config,
);

my $backup = $svc->create_backup();
ok(-f $backup->{file_path}, 'backup file created');

my $content;
gunzip($backup->{file_path} => \$content)
    or die "gunzip failed: $GunzipError";

# The backup_history table must NOT be in the dump, so restoring a backup
# never overwrites the live history / orphans the Drive archive.
unlike($content, qr/CREATE TABLE [`"]?backup_history/i,
    'dump does NOT contain CREATE TABLE for backup_history');
unlike($content, qr/INSERT INTO [`"]?backup_history/i,
    'dump does NOT contain INSERT INTO backup_history');

# Sanity: other tables ARE still dumped.
like($content, qr/CREATE TABLE [`"]?tenants/i,
    'dump still contains other tables (tenants)');

unlink $backup->{file_path};

done_testing;
