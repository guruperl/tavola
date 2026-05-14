package Tabilet::Act::Model;

use strict;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub pubtopics {
	my $self = shift;
	my $extra = shift;

	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT apid, componentid, crud
FROM user_action_public
WHERE componentid=?", $extra->{componentid} || $self->{ARGS}->{componentid});
}

1;
