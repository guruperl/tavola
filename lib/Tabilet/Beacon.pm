package Tabilet::Beacon;

use strict;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Genelet::Dispatch;
use Genelet::Beacon;
use Tabilet::Config qw(load_config);

use vars qw(@ISA);
@ISA = qw(Genelet::Beacon);

my $ROOT = dirname(dirname(dirname(abs_path(__FILE__))));

__PACKAGE__->setup_accessors(
  config => load_config("$ROOT/conf/test.json"),
  lib    => "$ROOT/lib",
  ip     => '192.168.29.29',
  comps  => ["Project","Database","Role","Component","Nextpage","Act","Admin","Member","Team","Ds","Table","Fktable","Uniquetable","Nontable","Stored","Webhook","Paypal","Subscription","Tt","Ttpost"],
  tag    => 'json',
  header => {'Content-Type' => "application/x-www-form-urlencoded", 'Cookie' => "go_probe=1"}
);

1;
