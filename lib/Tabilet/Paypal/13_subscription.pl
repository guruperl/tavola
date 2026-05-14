#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../../..", "$Bin/../../../../perl";
use Tabilet::Config qw(load_config);
use JSON;
use Genelet::Dispatch;
use Data::Dumper;
use Tabilet::Paypal::Subscription;

my $c0 = load_config("$Bin/../../../conf/config.json");
my $p = Tabilet::Paypal::Subscription->new(%{$c0->{Custom}->{PAYPAL}});
my $query = {plan_name=>'Personal Plan', firstname=>"Peter", lastname=>"Bi", email=>"peterbi+005\@gmail.com"};
prepare_query($query);

my $err = $p->init_request_bearer() ||
	$p->insert($query);
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);


sub get_plan {
	my $plan_name = shift;
	my $products = {
  'Personal Plan'  => $ENV{TABILET_PAYPAL_PLAN_ID_PERSONAL},
  'Team Plan'      => $ENV{TABILET_PAYPAL_PLAN_ID_TEAM},
  'Enterprise Plan'=> $ENV{TABILET_PAYPAL_PLAN_ID_ENTERPRISE},
	};
	die "Missing PayPal plan id for $plan_name\n" unless $products->{$plan_name};
	return $products->{$plan_name};
}

sub get_context {
	return decode_json('{
    "brand_name": "Tabilet",
    "locale": "en-US",
    "user_action": "SUBSCRIBE_NOW",
    "payment_method": {
      "payer_selected": "PAYPAL",
      "payee_preferred": "IMMEDIATE_PAYMENT_REQUIRED"
    },
    "return_url":"https://www.tabilet.com/script/tabi/public/en/subscription?action=return",
    "cancel_url":"https://www.tabilet.com/script/tabi/public/en/subscription?action=cancel"
  }');
}

sub get_subscriber {
	my ($firstname, $lastname, $email) = @_;
	return decode_json(qq~{
    "name": { "given_name": "$firstname", "surname": "$lastname" },
    "email_address": "$email"
  }~);
}

sub prepare_query {
	my $query = shift;

	$query->{quantity} = 1;
	$query->{plan_id} = get_plan($query->{plan_name});
	$query->{application_context} = get_context();
	$query->{subscriber} = get_subscriber($query->{firstname}, $query->{lastname}, $query->{email});
	delete $query->{$_} for (qw(plan_name firstname lastname email));

	return;
}
