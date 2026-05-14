package Tabilet::Tt::Model;

use strict;
use Tabilet::Model;

use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub reply {
  my $self = shift;
  my $extra = shift;

  return $self->update($extra) || $self->process_after("reply", @_);
}

1;
