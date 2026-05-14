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
my $err = $p->init_request_bearer() || $p->topics(); 
die $err if $err;

warn Dumper $p->{LISTS};

exit(0);

=pod
 		{
          'products' => [
                          {
                            'name' => 'Developer',
                            'id' => 'PAYPAL_PRODUCT_ID_EXAMPLE',
                            'links' => [
                                         {
                                           'href' => 'https://api.sandbox.paypal                                                                                            .com/v1/catalogs/products/PAYPAL_PRODUCT_ID_EXAMPLE',
                                           'rel' => 'self',
                                           'method' => 'GET'
                                         }
                                       ],
                            'create_time' => '2020-03-17T17:16:05Z',
                            'description' => 'Developer Account'
                          },
                          {
                            'create_time' => '2020-03-17T17:28:42Z',
                            'description' => 'Team Account',
                            'name' => 'Team',
                            'id' => 'PAYPAL_PRODUCT_ID_EXAMPLE',
                            'links' => [
                                         {
                                           'href' => 'https://api.sandbox.paypal                                                                                            .com/v1/catalogs/products/PAYPAL_PRODUCT_ID_EXAMPLE',
                                           'rel' => 'self',
                                           'method' => 'GET'
                                         }
                                       ]
                          },
                          {
                            'description' => 'Enterprise Account',
                            'create_time' => '2020-03-18T10:06:39Z',
                            'links' => [
                                         {
                                           'href' => 'https://api.sandbox.paypal                                                                                            .com/v1/catalogs/products/PAYPAL_PRODUCT_ID_EXAMPLE',
                                           'method' => 'GET',
                                           'rel' => 'self'
                                         }
                                       ],
                            'id' => 'PAYPAL_PRODUCT_ID_EXAMPLE',
                            'name' => 'Enterprise'
                          }
                        ],
          'links' => [
                       {
                         'rel' => 'self',
                         'method' => 'GET',
                         'href' => 'https://api.sandbox.paypal.com/v1/catalogs/p                                                                                            roducts?page_size=10&page=1'
                       }
                     ]
        }
=cut
