#!/bin/sh
echo "Checking for non-core required Perl modules...";
cpan Net::Amazon::S3
cpan Term::ProgressBar
echo "\n\nInstalling FaithTree::Backup...";
./Makefile.PL
make
make install
echo "\n\nDon't forget to edit ftBackup.conf and place it in an appropriate location (see README.md)";