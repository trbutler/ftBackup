#!/usr/bin/perl

use strict;
use warnings;
use v5.12;
use ExtUtils::MakeMaker; 
 
WriteMakefile(
    NAME            => 'FaithTree::Backup',
    AUTHOR			=> 'Timothy R. Butler <timothy.butler@faithtree.com>',
    VERSION_FROM	=> 'lib/FaithTree/Backup.pm',
    LICENSE			=> 'gpl_2',
    PREREQ_PM		=> {
          'POSIX'	=> '0',
          'threads'	=> '0',
          'threads::shared'	=> '0',
          'Thread::Queue'	=> '0',
          'Net::Amazon::S3'	=> '0',
          'Amazon::S3'	=> '0',          
    },
    EXE_FILES => [
           'bin/ftBackup'
    ],
    META_MERGE    => {
        'meta-spec' => { version => 2 },
         resources => {
             repository => {
                 type => 'git',
                 url  => 'https://github.com/trbutler/ftBackup.git',
                 web  => 'https://github.com/trbutler/ftBackup',
             },
             bugtracker => {web => 'https://github.com/trbutler/ftBackup/issues'},
             homepage   => 'https://uninetsolutions.com',
         },
    },    
);

