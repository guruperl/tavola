package Unit;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../..", "$Bin/../../../../perl";
use Test::More;

BEGIN {
	plan skip_all => "Set TABILET_RUN_APP_TESTS=1 with a configured test database to run Tabilet app tests"
		unless $ENV{TABILET_RUN_APP_TESTS};
}

use Genelet::Test;
use Tabilet::Admin::Model;
use Tabilet::Admin::Filter;

use vars qw(@ISA);
@ISA = qw(Genelet::Test);

sub initialize {
  my $self = shift;

	return {
	config=>"$Bin/../../../conf/test.json",
	data=>"$Bin/unit.json",
	component=>"$Bin/component.json"
  };
}

package main;

Unit->runtests;
