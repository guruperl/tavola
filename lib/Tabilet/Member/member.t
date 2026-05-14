#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../..", "$Bin/../../../../perl";
use strict;
use JSON;
use Test::More;

BEGIN {
	plan skip_all => "Set TABILET_RUN_APP_TESTS=1 with a configured test database to run Tabilet app tests"
		unless $ENV{TABILET_RUN_APP_TESTS};
	plan tests => 1;
}

use Tabilet::Beacon;

my $public = Tabilet::Beacon->new(role=>"public");

my %newuser = (
    "memberid"=>888888,
    "action"=>"insert",
    "firstname"=>"Peter",
    "lastname"=>"Bi",
    "email"=>"peter\@kinet.com",
    "login"=>"peter",
    "passwd"=>"1234abcd",
    "confirmpass"=>"1234abcd",
    "street"=>"999 st",
    "city"=>"el monte",
    "state"=>"ca",
    "country"=>"usa"
);
my @user = %newuser;
my $resp = $public->post_mockup("member", [@user]);
is($resp->code, 200, "status code is 200");

exit(0);
