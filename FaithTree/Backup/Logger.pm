package FaithTree::Backup::Logger;

use v5.12;
use warnings;

sub new {
	my $class = shift;
	my $self;
	bless ($self, $class);
}

sub info {
	return 1;
}

1;