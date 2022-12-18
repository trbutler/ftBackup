#!/bin/sh
echo "Installing FaithTree::Backup..."
./Makefile.PL
make
make install
echo "Don't forget to edit ftBackup.conf and place it in an appropriate location (see README.md)";