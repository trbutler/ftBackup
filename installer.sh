#!/bin/sh
echo "Installing FaithTree::Backup..."
mkdir /var/cpanel/perl5/lib/FaithTree
mkdir /var/cpanel/perl5/lib/FaithTree/Backup
cp FaithTree/Backup.pm /var/cpanel/perl5/lib/FaithTree/
cp FaithTree/Backup/Logger.pm /var/cpanel/perl5/lib/FaithTree/Backup/
cpan Net::Amazon::S3
cpan Term::ProgressBar
/usr/local/cpanel/bin/manage_hooks add module FaithTree::Backup
 