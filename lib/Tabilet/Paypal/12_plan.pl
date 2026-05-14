#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../../..", "$Bin/../../../../perl";
use Tabilet::Config qw(load_config);
use JSON;
use Genelet::Dispatch;
use Data::Dumper;
use Tabilet::Paypal::Catalog;
use Tabilet::Paypal::Plan;

my $c0 = load_config("$Bin/../../../conf/config.json");
my $c = Tabilet::Paypal::Catalog->new(%{$c0->{Custom}->{PAYPAL}});
my $err = $c->init_request_bearer() || $c->topics();
die $err if $err;
my $lists = $c->lists();
my $ref = {};
$ref->{$_->{name}} = $_->{id} for @{$lists->{products}};

warn $ref->{Personal};
warn Dumper get_cycle('Personal');
warn Dumper get_preference();

my $p = Tabilet::Paypal::Plan->new();
$p->req($c->req());
$p->insert({
	product_id         => $ref->{Personal},
	billing_cycles     => get_cycle('Personal'),
	payment_preferences=> get_preference(),
	name               => "Personal Plan",
	description        => "Personal monthly plan"
}) || $p->insert({
	product_id         => $ref->{Team},
	billing_cycles     => get_cycle('Team'),
	payment_preferences=> get_preference(),
	name               => "Team Plan",
	description        => "Team's yearly plan"
}) || $p->insert({
	product_id         => $ref->{Enterprise},
	billing_cycles     => get_cycle('Enterprise'),
	payment_preferences=> get_preference(),
	name               => "Enterprise Plan",
	description        => "Enterprise's yearly plan"
}) || $p->topics();
die $err if $err;

warn Dumper $p->lists();

exit(0);


sub get_preference {
  return decode_json('{
    "auto_bill_outstanding": true,
    "setup_fee": { "value": "0", "currency_code": "USD" },
    "setup_fee_failure_action": "CONTINUE",
    "payment_failure_threshold": 2
  }'),
}

sub get_cycle {
	my $product_name = shift;
	my $billings = {
  Personal => '[
    {
      "frequency": { "interval_unit": "WEEK", "interval_count": 1 },
      "tenure_type": "TRIAL", "sequence": 1, "total_cycles": 1,
      "pricing_scheme": {"fixed_price": {"value":"0", "currency_code":"USD"}}
    },
    {
      "frequency": { "interval_unit": "MONTH", "interval_count": 1 },
      "tenure_type": "REGULAR", "sequence": 2, "total_cycles": 0,
      "pricing_scheme": {"fixed_price": {"value":"50", "currency_code":"USD"}}
    }
  ]',
  Team => '[
    {
      "frequency": { "interval_unit": "WEEK", "interval_count": 1 },
      "tenure_type": "TRIAL", "sequence": 1, "total_cycles": 1,
      "pricing_scheme": {"fixed_price": {"value":"0", "currency_code":"USD"}}
    },
    {
      "frequency": { "interval_unit": "YEAR", "interval_count": 1 },
      "tenure_type": "REGULAR", "sequence": 2, "total_cycles": 0,
      "pricing_scheme": {"fixed_price": {"value":"990", "currency_code":"USD"}}
    }
  ]',
  Enterprise => '[
    {
      "frequency": { "interval_unit": "WEEK", "interval_count": 1 },
      "tenure_type": "TRIAL", "sequence": 1, "total_cycles": 1,
      "pricing_scheme": {"fixed_price": {"value":"0", "currency_code":"USD"}}
    },
    {
      "frequency": { "interval_unit": "YEAR", "interval_count": 1 },
      "tenure_type": "REGULAR", "sequence": 2, "total_cycles": 0,
      "pricing_scheme": {"fixed_price": {"value":"9900", "currency_code":"USD"}}
    }
  ]'
	};

	return decode_json($billings->{$product_name});
}
