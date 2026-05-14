package Tabilet::Database::Model;

use strict;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub topics {
	my $self = shift;

	return $self->call_once({model=>"table", action=>"simple_topics"}, @_);
}
 
sub edit {
	my $self = shift;
	return unless $self->{ARGS}->{tableid};
	return $self->call_once({model=>"table", action=>"edit"}, @_);
}

sub delete {
	my $self = shift;
	return unless $self->{ARGS}->{tableid};
	return $self->call_once({model=>"table", action=>"delete"}, @_);
}

1;
