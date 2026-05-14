#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../../..", "$Bin/../../../../perl";
use Tabilet::Config qw(load_config);
use Genelet::Dispatch;
use Data::Dumper;
use Tabilet::Paypal::Simulate;

my $c = load_config("$Bin/../../../conf/config.json");
my $p = Tabilet::Paypal::Simulate->new(%{$c->{Custom}->{PAYPAL}});
my $err = $p->init_request_bearer() ||
	$p->insert({event_type=>"BILLING.SUBSCRIPTION.CREATED",
		webhook_id=>$c->{Custom}->{WEBHOOK}});
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);
