package tavola

import (
	"strconv"
	"strings"
)

func emitPerl(a *Archive, model *generationModel) {
	project := ucfirst(model.Project.Project)
	components := make([]string, 0, len(model.Components))
	for _, comp := range model.Components {
		components = append(components, ucfirst(comp.Name))
	}
	a.AddMode("script/app", []byte(perlApp(components)), 0755)
	a.AddString("lib/"+project+"/Filter.pm", perlProjectFilter(project))
	a.AddString("lib/"+project+"/Model.pm", perlProjectModel(project, model.Project.DBType))
	for _, comp := range model.Components {
		cap := ucfirst(comp.Name)
		a.AddString("lib/"+project+"/"+cap+"/component.json", comp.ComponentJS)
		a.AddString("lib/"+project+"/"+cap+"/Filter.pm", perlComponentFilter(project, cap))
		a.AddString("lib/"+project+"/"+cap+"/Model.pm", perlComponentModel(project, cap))
	}
}

func perlApp(components []string) string {
	quoted := make([]string, 0, len(components))
	for _, component := range components {
		quoted = append(quoted, strconv.Quote(component))
	}
	return `#!/usr/bin/perl

use lib qw(lib);

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

my $config = _config("conf/config.json");
Genelet::Dispatch::run($config, "lib", [` + strings.Join(quoted, ",") + `]);

exit;

sub _config {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $config = JSON->new->utf8(0)->decode(<$fh>);
	close $fh or die "Cannot close $path: $!";
	$config = _expand_env($config);
	$config->{Db} = _dbi_db($config->{Db}) if ref($config->{Db}) eq 'ARRAY';
	return $config;
}

sub _expand_env {
	my $value = shift;
	if (ref($value) eq 'HASH') {
		$value->{$_} = _expand_env($value->{$_}) for keys %$value;
		return $value;
	}
	if (ref($value) eq 'ARRAY') {
		$value->[$_] = _expand_env($value->[$_]) for 0 .. $#$value;
		return $value;
	}
	if (defined($value) && !ref($value) && $value =~ /^\$\{([A-Z_][A-Z0-9_]*)\}$/) {
		die "Missing required environment variable $1" unless exists $ENV{$1};
		return $ENV{$1};
	}
	return $value;
}

sub _dbi_db {
	my $db = shift;
	return [ map { _dbi_db($_) } @$db ] if ref($db->[0]) eq 'ARRAY';
	my @copy = @$db;
	$copy[0] = _dbi_dsn($copy[0]);
	return \@copy;
}

sub _dbi_dsn {
	my $dsn = shift || '';
	return $dsn if $dsn =~ /^dbi:/i;
	return "dbi:mysql:$1" if $dsn =~ /^mysql:(.*)$/i;
	return "dbi:Pg:$1" if $dsn =~ /^pgsql:(.*)$/i;
	return "dbi:SQLite:dbname=$1" if $dsn =~ /^sqlite:(.*)$/i;
	return $dsn;
}
`
}

func perlProjectFilter(project string) string {
	return `package ` + project + `::Filter;

use strict;
use Genelet::Utils;
use Genelet::Filter;
use Genelet::Template;

use vars qw(@ISA);

@ISA = qw(Genelet::Filter Genelet::Template);

sub preset {
    my $self = shift;
    my $err  = $self->SUPER::preset(@_);
    return $err if $err;

    my $ARGS   = $self->{ARGS};
    my $action = $ARGS->{g_action};

    if ($action eq 'topics') {
        $ARGS->{rowcount} ||= 100;
        $ARGS->{pageno}   ||= 1;
    }

    if ($action eq 'insert') {
        $ARGS->{ip} = get_lb_ip();
        $ARGS->{created} ||= Genelet::Utils::now_from_unix($ARGS->{_gtime});
    }

    return;
}

sub before {
    my $self = shift;
    my $err  = $self->SUPER::before(@_);
    return $err if $err;
    return;
}

sub after {
    my $self = shift;
    my $err  = $self->SUPER::after(@_);
    return $err if $err;
    return;
}

sub get_lb_ip {
  if ( ($ENV{REMOTE_ADDR} =~ /^192\.168\./ or $ENV{REMOTE_ADDR} =~ /^10\./)
	and $ENV{HTTP_X_FORWARDED_FOR}
	and ($ENV{HTTP_X_FORWARDED_FOR} =~ /(\d+\.\d+\.\d+\.\d+)$/)) {
    return $1;
  } elsif ( ($ENV{REMOTE_ADDR} =~ /^192\.168\./ or $ENV{REMOTE_ADDR} =~ /^10\./)
	and $ENV{HTTP_X_REAL_IP}
	and ($ENV{HTTP_X_REAL_IP} =~ /(\d+\.\d+\.\d+\.\d+)$/)) {
    return $1;
  } else {
    $ENV{REMOTE_ADDR} =~ /(\d+\.\d+\.\d+\.\d+)$/;
    return $1;
  }
}
1;
`
}

func perlProjectModel(project, dbType string) string {
	adapter := "Mysql"
	switch dbFamily(dbType) {
	case "postgresql":
		adapter = "Pg"
	case "sqlite":
		adapter = "SQLite"
	}
	return `package ` + project + `::Model;

use strict;
use Genelet::Model;
use Genelet::` + adapter + `;

use vars qw(@ISA);
@ISA = qw(Genelet::Model Genelet::` + adapter + `);

__PACKAGE__->setup_accessors(
    'total_force' => 1,
);
1
`
}

func perlComponentFilter(project, comp string) string {
	return `package ` + project + `::` + comp + `::Filter;

use strict;
use ` + project + `::Filter;
use vars qw(@ISA);

@ISA=('` + project + `::Filter');

sub preset {
    my $self = shift;
    my $err  = $self->SUPER::preset(@_);
    return $err if $err;
    return;
}

sub before {
    my $self = shift;
    my $err  = $self->SUPER::before(@_);
    return $err if $err;
    return;
}

sub after {
    my $self = shift;
    my $err  = $self->SUPER::after(@_);
    return $err if $err;
    return;
}
1;
`
}

func perlComponentModel(project, comp string) string {
	return `package ` + project + `::` + comp + `::Model;

use strict;
use ` + project + `::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('` + project + `::Model');

1;
`
}
