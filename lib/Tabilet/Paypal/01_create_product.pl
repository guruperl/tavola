#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../../..", "$Bin/../../../../perl";
use Tabilet::Config qw(load_config);
use Genelet::Dispatch;
use Data::Dumper;
use Tabilet::Paypal::Catalog;

my $c = load_config("$Bin/../../../conf/config.json");
my $p = Tabilet::Paypal::Catalog->new(%{$c->{Custom}->{PAYPAL}});
my $err = $p->init_request_bearer() ||
	$p->insert({name=>"Enterprise", description=>"Enterprise Account"}); 
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);
