#!/usr/bin/perl
# FaithTree.com cPanel Incremental to S3 Backup Tool
# 
# A tool to take daily incremental backups from cPanel, upload them to S3 and rotate the copies on S3.
#
# Copyright (C) 2022 Universal Networks, LLC
# Note: this code is provided as is with NO WARRANTY. Use at your own risk.
#
# 	This program is free software: you can redistribute it and/or modify it
# 	under the terms of the GNU General Public License as published by the
# 	Free Software Foundation, either version 2 of the License, or (at your
# 	option) any later version. This program is distributed in the hope that
# 	it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# 	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# 	GNU General Public License for more details. You should have received a
# 	copy of the GNU General Public License along with this program. If not,
# 	see <https://www.gnu.org/licenses/>.

use v5.12;
use warnings;
 
# Load Configuration 
use Config::Simple;
use File::HomeDir;

my $configurationFile;
if (-e '/etc/ftBackup') {
	$configurationFile = "/etc/ftBackup";
}
elsif (-e File::HomeDir->my_home . ".ftBackup") {
	$configurationFile = File::HomeDir->my_home . ".ftBackup";
}
elsif (-e 'ftBackup.conf')
	$configurationFile = 'ftBackup.conf';
}
else {
	die "No configuration file found.";
}

Config::Simple->import_from($configurationFile, \%config);

use Net::Amazon::S3;

### Configuration

# cPanel Backup Path
my $backupPath = '/backup';

# define your bucket name and the prefix for your backups
our $bucketName = 'redcedarbackup';

# Number of daily backups to retain
our $retainBackups = 3;

### End of Configuration

say STDOUT 'FaithTree.com cPanel Incremental to S3 Backup Tool';
say STDOUT 'Sponsored by FaithTree.com -- please check us out!';
say STDOUT 'Copyright (C) 2022 Universal Networks, LLC';
say STDOUT 'By using this program the user acknowledges there is NO WARRANTY provided and';
say STDOUT "accepts the terms of the software license, which is the GNU GPL 2.0 or later.\n";

# create an S3 client
our $s3 = Net::Amazon::S3->new({
		aws_access_key_id  => $config{'access_key_id'},
		aws_secret_access_key => $config{'access_key'},
		retry => 1
	});

# Create bucket object
our $s3Bucket = $s3->bucket($bucketName);

# Do today's backup
# Directory grep based on https://stackoverflow.com/a/5751949/656780
opendir my $backupDirectory, $backupPath or die "$0: opendir: $!";
my @rawDirectories = grep { -d "$backupPath/$_" && ! /^\.{1,2}$/ && /^\d{4}-\d{2}-\d{2}$/ } readdir($backupDirectory); 
my @sortedDirectories = sort { $b cmp $a } @rawDirectories;
closedir $backupDirectory;

# List eligible items
my $backupTarget = $backupPath . '/' . $sortedDirectories[0] . '/accounts/';
opendir ($backupDirectory, $backupTarget) or die "$0: opendir: $!";
my @files = grep { ! /^\./ } readdir($backupDirectory); 
closedir $backupDirectory;

foreach my $target (@files) {
	my $file = $backupTarget . $target;
	print 'Backing up ' . $file . '...';
	`tar -czf $file.tar.gz $file > /dev/null 2>&1`;
	$s3Bucket->add_key_filename($backupPath . '/daily/' . $sortedDirectories[0] . '/' . $target . '.tar.gz', $file . '.tar.gz') or die "Failed to delete object: $!";
	print "Done.\n";
	unlink $file . '.tar.gz';
}

# Cull old backups
# get the list of daily backups from S3
my $backupOutput = $s3->list_bucket({
    	bucket => $bucketName,
    	prefix => 'backup/daily/',
    	delimiter => "/"
    }
) or die "Failed to list objects from S3: $!";


# sort the backups by date
my @backups = sort { $a cmp $b } @{ $backupOutput->{'common_prefixes'} };

# get the latest daily backup
my $latestDailyBackup = $backups[0];

# copy the latest daily backup to create the weekly backup
my $dayOfMonth = (localtime)[3];
my $dayOfWeek = (localtime)[6];
my $dayOfYear = (localtime)[7];

# If it's the second day of the month and the first day of the week,
# run on the third day of the month instead
if (($dayOfMonth != 2 && $dayOfWeek == 1) or ($dayOfMonth == 3 && $dayOfWeek == 2) or (! &doesBackupExist({ 'target' => 'backup/weekly/'}))) {
	print 
	&copyDirectory({ 'source' => $latestDailyBackup . "/", 'destination' => 'backup/weekly/' });
}

# copy the latest daily backup to create the monthly backup
if (($dayOfMonth == 2) or (! &doesBackupExist({ 'target' => 'backup/monthly/'}))) {
	&copyDirectory({ 'source' => $latestDailyBackup, 'destination' => 'backup/monthly/' });
}

# copy the latest daily backup to create the yearly backup
if (($dayOfYear == 1) or (! &doesBackupExist({ 'target' => 'backup/yearly/'}))) {
	&copyDirectory({ 'source' => $latestDailyBackup, 'destination' => 'backup/yearly/' });
}

# delete old daily backups if there are more than 3 of them
if (@backups > $retainBackups) {
    for my $i (0..$#backups-$retainBackups) {
    	print 'Deleting old backup ' . $backups[$i] . "...\n";
        my $backup = $backups[$i];
        &deleteDirectory({ 'target' => $backup });
    }
}

sub deleteDirectory {
	my $params = shift;

	# Delete child objects.
	my $itemsToDelete = $s3->list_bucket({
			bucket => $bucketName,
			prefix => $params->{'target'},
		}
	) or print STDERR "Failed to list child objects from S3: $!";
	
	foreach (@{ $itemsToDelete->{'keys'} }) {
		print "	Deleting " . $_->{'key'} . "...";
		
        $s3Bucket->delete_key($_->{'key'}) or die "Failed to delete object: $!";
		print "Done.\n";
	}
	
	# Delete directory.
	$s3Bucket->delete_key($params->{'target'});
	
	return ($s3Bucket->err) ? 0 : 1;

}

sub copyDirectory {
	my $params = shift;
	
	# Get objects to copy
	my $itemsToCopy = $s3->list_bucket({
			bucket => $bucketName,
			prefix => $params->{'source'},
		}
	) or print STDERR "Failed to list daily objects from S3: $!";
	
	foreach (@{ $itemsToCopy->{'keys'} }) {
		print "Copying " . $_->{'key'} . ' to ' . $params->{'destination'} . '...';
		
		my ($file) = $_->{'key'} =~ m#.*/(.*?)$#;

		$s3Bucket->copy_key(
			key => $params->{'destination'} . $file,
			source => '/' . $bucketName . '/' . $_->{'key'}
		) or say STDERR "Failed to copy object $_->{'key'} to $params->{'destination'}:" . $s3Bucket->errstr;
	
		print "Done.\n";
	}
	
	return ($s3Bucket->err) ? 0 : 1;
}

sub doesBackupExist {
	my $params = shift;
	
	my $targetCheck = $s3->list_bucket({
			bucket => $bucketName,
			prefix => $params->{'target'}
		});
	
	return (!@{ $targetCheck->{'keys'} }) ? 0 : 1;
}

1;