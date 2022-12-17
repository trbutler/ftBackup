# !/usr/bin/perl
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
# 	it will be useful, but WITHOUT ANY WARRANTY; without even the impliNed
# 	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# 	GNU General Public License for more details. You should have received a
# 	copy of the GNU General Public License along with this program. If not,
# 	see <https://www.gnu.org/licenses/>.

package FaithTree::Backup;

use v5.12;
use warnings;
use POSIX;
use Term::ProgressBar;
use threads;
use threads::shared;
use Thread::Queue;
use HTTP::Request::Common; 
use Net::Amazon::S3;
use Amazon::S3;

# Are we operating as a hook for cPanel?
my $logger;
my $testForCpanel = eval { 
	require Cpanel::Logger;	
	$logger = Cpanel::Logger->new();
};

unless ($testForCpanel) {
	require FaithTree::Backup::Logger;
	$logger = FaithTree::Backup::Logger->new();
}

our $cpanelMode = ($testForCpanel) ? 1 : 0;

# Fix bugs in Net::Amazon:S3
*Net::Amazon::S3::Client::Object::put_part = sub {
    my $self = shift;

    my %args = ref($_[0]) ? %{$_[0]} : @_;

    #work out content length header
    $args{headers}->{'Content-Length'} = length $args{value}
        if(defined $args{value});

    my $response = $self->_perform_operation (
        'Net::Amazon::S3::Operation::Object::Upload::Part',

        upload_id   => $args{upload_id},
        part_number => $args{part_number},
        headers     => $args{headers},
        value       => $args{value},
    );

    return $response->http_response;
}; 

*Net::Amazon::S3::Response::is_xml_content = sub {
        my ($self) = @_;

        #return $self->content_type =~ m:[/+]xml\b: && $self->decoded_content;
        return $self->decoded_content && $self->decoded_content =~ /^\Q<?xml\E/;
};


### Load Configuration

my %config;
Config::Simple->import_from($configurationFile, \%config);

# cPanel Backup Path
my $backupPath = $config{'backupPath'};

# define your bucket name and the prefix for your backups
our $bucketName = $config{'bucketName'};

# Number of daily backups to retain
our $retainBackups = $config{'retainBackups'};

our ($s3, $s3Bucket, $simpleS3);


# Are we running as a script or as a module?
InitiateBackup() unless caller;
 
# Set up hook for cPanel usage
sub describe {
    my $hooks = [
        {
            'category' => 'System',
            'event'    => 'Backup',
            'stage'    => 'post',
            'hook'     => 'FaithTree::Backup::InitiateBackup',
            'exectype' => 'module',
        }
    ];
    return $hooks;
}

# Core Program Logic
sub InitiateBackup {
	# Load Configuration 
	use Config::Simple;
	use File::HomeDir;

	my $configurationFile;
	if (-e File::HomeDir->my_home . "/.ftBackup") {
		$configurationFile = File::HomeDir->my_home . "/.ftBackup";
	}
	elsif (-e '/etc/ftBackup') {
		$configurationFile = "/etc/ftBackup";
	}
	elsif (-e 'ftBackup.conf') {
		$configurationFile = 'ftBackup.conf';
	}
	else {
		die "No configuration file found.";
	}

	say STDOUT 'FaithTree.com cPanel Incremental to S3 Backup Tool';
	say STDOUT 'Sponsored by FaithTree.com -- please check us out!';
	say STDOUT 'Copyright (C) 2022 Universal Networks, LLC';
	say STDOUT 'By using this program the user acknowledges there is NO WARRANTY provided and';
	say STDOUT "accepts the terms of the software license, which is the GNU GPL 2.0 or later.\n";

	# create our S3 clients
	# We use Net::Amazon::S3 for most operations since it supports copying.
	# However, its multipart support is buggy and we use Amazon::S3 for that.
	
	$s3 = Net::Amazon::S3->new({
			aws_access_key_id  => $config{'access_key_id'},
			aws_secret_access_key => $config{'access_key'},
			retry => 1
		});
	
	$s3Bucket = $s3->bucket($bucketName);
	
	$simpleS3 = Amazon::S3->new({
			aws_access_key_id  => $config{'access_key_id'},
			aws_secret_access_key => $config{'access_key'},
			retry => 1
		});	

		# FIXME: Remove this.
		#my $backupTarget = '/backup/2022-12-13/accounts/';
		#my $target = 'asisaid';
		#my @sortedDirectories = ( '2022-12-13' );

		# Test code
	
		# exit;


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
		my $archive = $backupTarget . $target . '.tar.gz';	
		my $destinationObject = $backupPath . '/daily/' . $sortedDirectories[0] . '/' . $target . '.tar.gz';

		print 'Backing up ' . $file . '...';
		$logger->info('Backing up ' . $file);
		`tar -czf $archive $file > /dev/null 2>&1`;
	
		my $size = -s $archive;  
		my $chunkSize = 500 * 1024 * 1024;
		my $parts = ceil($size / $chunkSize);
		my @queueData;
		for (1...$parts) { push (@queueData, $_); }
		my $overallProgress :shared;
		my $queue = Thread::Queue->new(@queueData);

		# Setup Progress Bar
		my $progress = Term::ProgressBar->new({name  => $target,
											   count => $parts,
											   ETA   => 'linear', 
											   remove => 1 });

		# Initiate upload.
		my $bucket = $simpleS3->bucket($bucketName); 
		my $uploadId = $bucket->initiate_multipart_upload($destinationObject);
		my %partList :shared;

		$logger->info("We need " . $parts . " parts for this upload.");

		my @threads;
		for(1..4) {
			push @threads, threads->create( sub {
				# Open file handle for thread.
				open(my $fileHandle, '<', $archive) or die("Error reading file, stopped");
				binmode($fileHandle); 		
			
				# Pull work from the queue, don't wait if its empty
				while( my $i = $queue->dequeue_nb ) {
					my $chunk;
					my $offset = ($i - 1) * $chunkSize;

					seek ($fileHandle, $offset, 0);
			
					if ($chunkSize > $size) {
						$chunkSize = $size;
					}
					elsif (($chunkSize + $offset) > $size) {
						$chunkSize = $size - $offset;
					}
				
					say STDERR "Chunk size for $i: " . $chunkSize . " starting at " . $offset if ($config{'debug'});

					my $length = read($fileHandle, $chunk, $chunkSize);	

					if ($config{'debug'}) {
						say STDOUT "Chunk diff: " . (length($chunk) - $chunkSize);
						say STDOUT "Requested size: " . $chunkSize;	
						say STDOUT "Received size: " . length($chunk);
						say STDOUT "Stated size: " . $length;
					}

					my $bucketStep = $simpleS3->bucket($bucketName); 
					$partList{$i} = $bucketStep->upload_part_of_multipart_upload($destinationObject, $uploadId, $i, $chunk);

					unless ($partList{$i}) {
						$logger->info("Going to need to repeat chunk " . $i . ".");
						$queue->enqueue($i);
						next;
					}		

					#Advance Progress Bar
					$overallProgress++;			
					$progress->update($overallProgress);
					$progress->message( 'Number: ' . $i);
				}
			
				# Close file handle for thread.
				close($fileHandle); 
		   });
		}

		# Wait for threads to finish
		$_->join for @threads;


		my $result = $bucket->complete_multipart_upload($destinationObject, $uploadId, \%partList);	
	
		unless ($result) {
			$logger->info('Failed to upload ' . $target . ' backup');
			die;
		}

		print "Done.\n";
		unlink $archive;
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
	print STDOUT "Checking on weekly/monthly/yearly rotations...";

	if (($dayOfMonth != 2 && $dayOfWeek == 1) or ($dayOfMonth == 3 && $dayOfWeek == 2) or (! &doesBackupExist({ 'target' => 'backup/weekly/'}))) {
		$logger->info('Preparing weekly backup.');
		&copyDirectory({ 'source' => $latestDailyBackup . "/", 'destination' => 'backup/weekly/' });
	}

	# copy the latest daily backup to create the monthly backup
	if (($dayOfMonth == 2) or (! &doesBackupExist({ 'target' => 'backup/monthly/'}))) {
		$logger->info('Preparing monthly backup.');
		&copyDirectory({ 'source' => $latestDailyBackup, 'destination' => 'backup/monthly/' });
	}

	# copy the latest daily backup to create the yearly backup
	if (($dayOfYear == 1) or (! &doesBackupExist({ 'target' => 'backup/yearly/'}))) {
		$logger->info('Preparing yearly backup.');
		&copyDirectory({ 'source' => $latestDailyBackup, 'destination' => 'backup/yearly/' });
	}
	print STDOUT " Done.\n";

	# delete old daily backups if there are more than 3 of them
	if (@backups > $retainBackups) {
		for my $i (0..$#backups-$retainBackups) {
			my $message = 'Deleting old backup ' . $backups[$i];
			print $message . "...\n";
			$logger->info($message);
			my $backup = $backups[$i];
			&deleteDirectory({ 'target' => $backup });
		}
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
		my $message = "	Deleting " . $_->{'key'};
    	print $message . "...\n";
    	$logger->info($message);
		
        $s3Bucket->delete_key($_->{'key'}) or die "Failed to delete object: $!";
		print " Done.\n";
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
	
		print " Done.\n";
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