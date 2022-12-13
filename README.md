# ftBackup
A tool to take daily incremental backups from cPanel, upload them to S3 and rotate the copies on S3.

# Installation
Download the code:

    git clone git@github.com:trbutler/ftBackup.git

Edit the default configuration file ('ftBackup.conf') with your Amazon S3 credentials. Other settings in this file are commented for explanation. This file can be left in the same directory as ftBackup or can be saved as `~/.ftBackup` or `/etc/ftBackup`.

# Operation

Simply run `perl ftBackup.pl`.
