#!/bin/sh
echo "Installing FaithTree::Backup..."
mkdir /var/cpanel/perl5/lib/FaithTree
mkdir /var/cpanel/perl5/lib/FaithTree/Backup
cp FaithTree/Backup.pm /var/cpanel/perl5/lib/FaithTree/
cp FaithTree/Backup/Logger.pm /var/cpanel/perl5/lib/FaithTree/Backup/
cp ftBackup.pl /var/cpanel/perl5/lib/
ln -s /usr/local/bin/ftBackup /var/cpanel/perl5/lib/ftBackup.pl
chmod 700 /usr/local/bin/ftBackup
cpan Net::Amazon::S3
cpan Term::ProgressBar
/usr/local/cpanel/bin/manage_hooks add module FaithTree::Backup
 