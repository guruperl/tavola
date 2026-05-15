package Tabilet::Generator::Perl;

use strict;
use Tabilet::Generator::Config;
use vars qw($AUTOLOAD @ISA);
@ISA = qw(Tabilet::Generator::Config);

__PACKAGE__->setup_accessors(
    components => undef,
);

sub project_filter {
	my $self = shift;
	my $project = ucfirst $self->{PROJECT}->{Project};

	return qq~package ~.$project.qq~::Filter;

use strict;
use Genelet::Utils;
use Genelet::Filter;
use Genelet::Template;

use vars qw(\@ISA);

\@ISA = qw(Genelet::Filter Genelet::Template);

sub preset {
    my \$self = shift;
    my \$err  = \$self->SUPER::preset(\@_);
    return \$err if \$err;

    my \$ARGS   = \$self->{ARGS};
    my \$action = \$ARGS->{g_action};

    if (\$action eq 'topics') {
        \$ARGS->{rowcount} ||= 100;
        \$ARGS->{pageno}   ||= 1;
    }

    if (\$action eq 'insert') {
        \$ARGS->{ip} = get_lb_ip();
        \$ARGS->{created} ||= Genelet::Utils::now_from_unix(\$ARGS->{_gtime});
    }

    return;
}

sub before {
    my \$self = shift;
    my \$err  = \$self->SUPER::before(\@_);
    return \$err if \$err;

    my (\$form, \$extra, \$nextextras) = \@_;

    return;
}

sub after {
    my \$self = shift;
    my \$err  = \$self->SUPER::after(\@_);
    return \$err if \$err;

    my (\$form) = \@_;
    my \$lists = \$form->{LISTS};

    return;
}

sub get_lb_ip {
  if ( (\$ENV{REMOTE_ADDR} =\~ /^192\\.168\\./ or \$ENV{REMOTE_ADDR} =\~ /^10\\./)
	and \$ENV{HTTP_X_FORWARDED_FOR}
	and (\$ENV{HTTP_X_FORWARDED_FOR} =\~ /(\\d+\\.\\d+\\.\\d+\\.\\d+)\$/)) {
    return \$1;
  } elsif ( (\$ENV{REMOTE_ADDR} =\~ /^192\\.168\\./ or \$ENV{REMOTE_ADDR} =\~ /^10\\./)
	and \$ENV{HTTP_X_REAL_IP}
	and (\$ENV{HTTP_X_REAL_IP} =\~ /(\\d+\\.\\d+\\.\\d+\\.\\d+)\$/)) {
    return \$1;
  } else {
    \$ENV{REMOTE_ADDR} =\~ /(\\d+\\.\\d+\\.\\d+\\.\\d+)\$/;
    return \$1;
  }
}
1;
~;
}

sub project_model {
	my $self = shift;
    my $project = ucfirst $self->{PROJECT}->{Project};

    return qq~package ~.$project.qq~::Model;

use strict;
use Genelet::Model;
use Genelet::Mysql;

use vars qw(\@ISA);
\@ISA = qw(Genelet::Model Genelet::Mysql);

__PACKAGE__->setup_accessors(
    'total_force' => 1,
);
1
~;
}

sub app {
	my $self = shift;
    my $json = shift;
	my $lib  = shift;

	return qq~#!/usr/bin/perl

use lib qw($lib);

use strict;
use JSON;

use DBI;
use LWP::UserAgent;

use File::Find;
use Data::Dumper;
use URI;
use URI::Escape();
use Digest::HMAC_SHA1;
use MIME::Base64();
use Template;

use Genelet::Dispatch;

Genelet::Dispatch::run("$json","$lib", ["~.join('","', map {ucfirst} @{$self->{COMPONENTS}}).qq~"]);

exit;
~;
}

sub project_beacon {
	my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};
	my $str = join('","', @{$self->{COMPONENTS}});	

	return qq~<?php
declare (strict_types = 1);

namespace $project;
use PDO;

use Genelet;

class Beacon extends \\Genelet\\Beacon
{
    public function __construct(string \$role) {
        \$ip  = "192.168.1.2";
        \$tag = "json";
        \$headers = ['Content-Type'=>"application/x-www-form-urlencoded", 'Cookie' => array("go_probe"=>"/")];
        \$c = json_decode(file_get_contents(__DIR__."/../conf/config.json"));
        \$logger = new \\Genelet\\Logger(\$c->{"Log"}->{"Filename"}, \$c->{"Log"}->{"Level"});
        \$pdo = new \\PDO(...\$c->{"Db"});
        \$jsons = array();
        \$storage = array();
        foreach (["~.$str.qq~"] as \$item) {
            \$jsons[\$item] = json_decode(file_get_contents(__DIR__."/\$item/component.json"));
            \$class = '\\\\'."$project".'\\\\'.ucfirst(\$item).'\\\\'."Model";
            \$storage[\$item]  = new \$class(\$pdo, \$jsons[\$item]);
        }
        parent::__construct(\$c, \$pdo, \$jsons, \$storage, \$logger, \$role, \$tag, \$ip, \$headers);
    }
}
~
}

sub filter {
    my $self = shift;

	my $project = ucfirst $self->{PROJECT}->{Project};
	my $comp    = ucfirst $self->{COMPONENT}->{name_component};

	return qq~package ~.$project.qq~::~.$comp.qq~::Filter;

use strict;
use ~.$project.qq~::Filter;
use vars qw(\@ISA);

\@ISA=('~.$project.qq~::Filter');

sub preset {
    my \$self = shift;
    my \$err  = \$self->SUPER::preset(\@_);
    return \$err if \$err;

    my \$ARGS   = \$self->{ARGS};
    my \$r      = \$self->{R};
    my \$role   = \$ARGS->{g_role};
    my \$action = \$ARGS->{g_action};

    return;
}

sub before {
    my \$self = shift;
    my \$err  = \$self->SUPER::before(\@_);
    return \$err if \$err;

    my \$ARGS   = \$self->{ARGS};
    my \$r      = \$self->{R};
    my \$role   = \$ARGS->{g_role};
    my \$action = \$ARGS->{g_action};

    my (\$form, \$extra, \$nextextras) = \@_;

    return;
}

sub after {
    my \$self = shift;
    my \$err  = \$self->SUPER::after(\@_);
    return \$err if \$err;

    my \$ARGS   = \$self->{ARGS};
    my \$r      = \$self->{R};
    my \$role   = \$ARGS->{g_role};
    my \$action = \$ARGS->{g_action};

    my (\$form) = \@_;
    my \$lists = \$form->{LISTS};

    return;
}
1;
~;
}

sub model {
    my $self = shift;

	my $project = ucfirst $self->{PROJECT}->{Project};
	my $comp    = ucfirst $self->{COMPONENT}->{name_component};

    return qq~package ~.$project.qq~::~.$comp.qq~::Model;

use strict;
use ~.$project.qq~::Model;
use vars qw(\$AUTOLOAD \@ISA);

\@ISA=('~.$project.qq~::Model');

1;
~;
}

1;
