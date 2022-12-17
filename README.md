# ftBackup
A tool to take daily incremental backups from cPanel, upload them to S3 and rotate the copies on S3.

# Installation
Download the code:

    git clone git@github.com:trbutler/ftBackup.git

You can run `./installer.sh` within the newly downloaded repository to install the program on a cPanel server and register it to run after the cPanel backup process. If you intend to use it on a non-cPanel server, simply place the repository itself wherever you would like to store the program and run it from there.

# Configuration
Edit the default configuration file ('ftBackup.conf') with your Amazon S3 credentials. Other settings in this file are commented for explanation. This file can be left in the same directory as ftBackup or can be saved as `~/.ftBackup` or `/etc/ftBackup`. The version located in your home directory is given first preference, then the global `/etc/` version and, finally, the one in the present working directory.

**Note:** if you use the home directory option and you want the process run automatically by cPanel, the configuration will need to be in root's home directory (e.g. /root/.ftBackup) not another user's home directory, since that is what user it will be run as.

# Warning Before Use
Backups of a cPanel server are, needless to say, incredibly important in most cases. This tool comes with absolutely no warranty and is provided to use at your own risk. Always check to make sure the backups are being uploaded successfully using another tool, such as the S3 console, rather than simply assuming this tool is working.

# Manual Operation
If you used the installer script, you can now simply run `ftBackup` from the command line as the user that you wish to have do the backup process. 

Alternately, to run it directly from the repository directory, just type `perl ftBackup.pl` in that directory.

# Automated Operation
This script's installer will register it to be run after cPanel completes its daily backup task. It is designed to assume that cPanel will be producing incremental (uncompressed) backups and then to compress and transfer those. 

If you would like to register it with cPanel's hook manager manually, rather than using the installer, use this command (replacing `/path/to/` with the location of the FaithTree::Backup repository):

	/usr/local/cpanel/bin/manage_hooks add script /path/to/ftBackup.pl --manual --category=System --event=Backup --stage=post
	
# Appreciate the Script?
If this script is useful to you and you'd like to say thank you, sending a couple bucks to @faithtree on Venmo or timothy.butler@faithtree.com on PayPal. Anything you send will be tax deductible in the United States as a gift to FaithTree Christian Fellowship, Inc., an IRS 501(c)(3) charity.

# About
This tool is copyright (c) 2022 Universal Networks, LLC. Check out our friends at [FaithTree.com](https://faithtree.com) and [OFB.biz - Open for Business](https://ofb.biz).
