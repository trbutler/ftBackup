# ftBackup
A tool to take daily incremental backups from cPanel, upload them to S3 and rotate the copies on S3.

# Installation
Download the code:

    git clone git@github.com:trbutler/ftBackup.git

Edit the default configuration file ('ftBackup.conf') with your Amazon S3 credentials. Other settings in this file are commented for explanation. This file can be left in the same directory as ftBackup or can be saved as `~/.ftBackup` or `/etc/ftBackup`. The version located in your home directory is given first preference, then the global `/etc/` version and, finally, the one in the present working directory.

# Operation
Simply run `perl ftBackup.pl`.

# Warning Before Use
Backups of a cPanel server are, needless to say, incredibly important in most cases. This tool comes with absolutely no warranty and is provided to use at your own risk. Always check to make sure the backups are being uploaded successfully using another tool, such as the S3 console, rather than simply assuming this tool is working.

# About
This tool is copyright (c) 2022 Universal Networks, LLC. Check out our friends at [FaithTree.com](https://faithtree.com) and [OFB.biz - Open for Business](https://ofb.biz).
