#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../../..", "$Bin/../../../../perl";
use Tabilet::Config qw(load_config);
use Genelet::Dispatch;
use Data::Dumper;
use Tabilet::Paypal::Subscription;

my $c = load_config("$Bin/../../../conf/config.json");
my $p = Tabilet::Paypal::Subscription->new(%{$c->{Custom}->{PAYPAL}});
my $err = $p->init_request_bearer() ||
	$p->insert({plan_name=>'Personal Plan', firstname=>"Peter", lastname=>"Bi", email=>"peterbi+005\@gmail.com"}); 
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);
