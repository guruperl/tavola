#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../../..", "$Bin/../../../../perl";
use Tabilet::Config qw(load_config);
use Genelet::Dispatch;
use Data::Dumper;
use Tabilet::Paypal::Plan;

my $c = load_config("$Bin/../../../conf/config.json");
my $p = Tabilet::Paypal::Plan->new(%{$c->{Custom}->{PAYPAL}});
my $err = $p->init_request_bearer() ||
	$p->insert({product_name=>'Enterprise', name=>"Enterprise Plan", description=>"Enterprise's yearly plan"}); 
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);
