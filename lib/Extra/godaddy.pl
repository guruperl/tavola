#! /usr/bin/perl

use strict;
use Net::SMTP::SSL;

my $smtp = Net::SMTP::SSL->new('smtpout.secureserver.net', Port => 465, Hello => 'tabilet.com', Debug => 1) or die $!;
defined($smtp->auth($ENV{TABILET_SMTP_USER}, $ENV{TABILET_SMTP_PASS})) or die $!;
$smtp->mail('info@tabilet.com') or die $!;
$smtp->to('peterbi@gmail.com') or die $!;
$smtp->data() or die $!;
$smtp->datasend("From: info\@tabilet.com\n") or die $!;
$smtp->datasend("To: peterbi\@gmail.com\n") or die $!;
$smtp->datasend("Subject: This is a test\n") or die $!;
$smtp->datasend("\n") or die $!;

$smtp->datasend("This is test #1.\n") or die $!;
$smtp->dataend or die $!;

$smtp->quit or die $!;

exit;
