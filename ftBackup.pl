#!/usr/bin/perl
use v5.12;
use File::Basename;
use lib dirname (__FILE__);
use FaithTree::Backup;

FaithTree::Backup::InitiateBackup();

1;