#!/bin/sh
echo "Installing FaithTree::Backup..."
mkdir /var/cpanel/perl5/lib/FaithTree
mkdir /var/cpanel/perl5/lib/FaithTree/Backup
cp FaithTree/Backup.pm /var/cpanel/perl5/lib/FaithTree/
cp FaithTree/Backup/Logger.pm /var/cpanel/perl5/lib/FaithTree/Backup/
cp ftBackup.pl /var/cpanel/perl5/lib/
ln -s /var/cpanel/perl5/lib/ftBackup.pl /usr/local/bin/ftBackup 
chmod 700 /var/cpanel/perl5/lib/ftBackup.pl
cpan Net::Amazon::S3
cpan Term::ProgressBar
/usr/local/cpanel/bin/manage_hooks add script /var/cpanel/perl5/lib/ftBackup.pl --manual --category=System --event=Backup --stage=post
 