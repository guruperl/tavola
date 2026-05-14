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
my $err = $p->init_request_bearer() || $p->topics(); 
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);

=pod
	{
          'links' => [
                       {
                         'href' => 'https://api.sandbox.paypal.com/v1/billing/plans?page_size=10&page=1',
                         'method' => 'GET',
                         'rel' => 'self'
                       }
                     ],
          'plans' => [
                       {
                         'id' => 'PAYPAL_PLAN_ID_EXAMPLE',
                         'status' => 'ACTIVE',
                         'links' => [
                                      {
                                        'rel' => 'self',
                                        'method' => 'GET',
                                        'href' => 'https://api.sandbox.paypal.com/v1/billing/plans/PAYPAL_PLAN_ID_EXAMPLE'
                                      }
                                    ],
                         'name' => 'Personal Plan',
                         'description' => 'Single user\'s monthly plan',
                         'create_time' => '2020-03-18T14:10:25Z'
                       },
                       {
                         'id' => 'PAYPAL_PLAN_ID_EXAMPLE',
                         'status' => 'ACTIVE',
                         'links' => [
                                      {
                                        'rel' => 'self',
                                        'method' => 'GET',
                                        'href' => 'https://api.sandbox.paypal.com/v1/billing/plans/PAYPAL_PLAN_ID_EXAMPLE'
                                      }
                                    ],
                         'name' => 'Team Plan',
                         'description' => 'Team\'s yearly plan',
                         'create_time' => '2020-03-18T14:11:57Z'
                       },
                       {
                         'id' => 'PAYPAL_PLAN_ID_EXAMPLE',
                         'status' => 'ACTIVE',
                         'links' => [
                                      {
                                        'method' => 'GET',
                                        'href' => 'https://api.sandbox.paypal.com/v1/billing/plans/PAYPAL_PLAN_ID_EXAMPLE',
                                        'rel' => 'self'
                                      }
                                    ],
                         'name' => 'Enterprise Plan',
                         'description' => 'Enterprise\'s yearly plan',
                         'create_time' => '2020-03-18T14:15:20Z'
                       }
                     ]
        }
=cut
