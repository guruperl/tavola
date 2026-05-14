package Tabilet::Filter;

use strict;
use Digest::SHA qw(sha1_hex);
use Genelet::Utils;
use Genelet::Filter;
use Genelet::Template;
use Genelet::SMTP;
use Genelet::CGI;
#use Genelet::Gmail;

use vars qw(@ISA);

#@ISA = qw(Genelet::Filter Genelet::Template Genelet::Gmail);
@ISA = qw(Genelet::CGI Genelet::Filter Genelet::Template Genelet::SMTP);

sub preset {
  my $self = shift;
  my $err  = $self->SUPER::preset(@_);
  return $err if $err;

  my $ARGS = $self->{ARGS};
  my $r    = $self->{R};
  my $who  = $ARGS->{_gwho};
  my $action = $ARGS->{_gaction};
  my $obj  = $ARGS->{_gobj};

  if ($action eq 'topics') {
#    $ARGS->{rowcount} ||= 100;
#    $ARGS->{pageno}   ||= 1;
  }

  if ($action eq 'insert' or $action eq 'reply' or $action eq 'activate') {
    $ARGS->{ip} = get_lb_ip();
    $ARGS->{createdint} = $ARGS->{_gtime};
    $ARGS->{created} ||= Genelet::Utils::now_from_unix($ARGS->{_gtime});
  }

  return;
}

sub digest_simple {
  my $self = shift;
  my $name = shift;
  my $ARGS = $self->{ARGS};

  return $self->digest($self->{SECRET}, $ARGS->{_gwhen}.$ARGS->{_gwho}.$ARGS->{$ARGS->{_gidname}}.$ARGS->{$name});
}

sub member2project {
  my $self = shift;
  my $form = shift;
  my $ARGS = $self->{ARGS};

  my $err  = $form->get_args($ARGS,
"SELECT projectid
FROM user_project
WHERE memberid=?", $ARGS->{memberid});
  return $err if $err;
  return unless $ARGS->{projectid};

  $ARGS->{projectmd5} = $self->digest_simple("projectid");
  return;
}

sub before {
  my $self = shift;
  my $err  = $self->SUPER::before(@_);
  return $err if $err;

  my ($form, $extra, $nextextras) = @_;
  my $dbh = $form->{DBH};

  my $ARGS = $self->{ARGS};
  my $r    = $self->{R};
  my $who  = $ARGS->{_gwho};
  my $action = $ARGS->{_gaction};
  my $obj  = $ARGS->{_gobj};

  if (($action eq 'topics' and grep {$obj eq $_} qw(role component database nextpage))
	or ($action eq 'startnew' and $obj eq 'role')) {
    $err = $self->member2project($form) and return $err;
  }

  return;
}

sub after {
  my $self = shift;
  my $err  = $self->SUPER::after(@_);
  return $err if $err;

  my ($form) = @_;

  my $ARGS = $self->{ARGS};
  my $r = $self->{R};
  my $who = $ARGS->{_gwho};
  my $action = $ARGS->{_gaction};
  my $obj = $ARGS->{_gobj};

  return;
}

sub proc_name {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	return 3206 unless ($ARGS->{authen} and $ARGS->{login} and $ARGS->{table_name} and $ARGS->{name_role});

    my $proc = ($ARGS->{authen} and ($ARGS->{authen} ne 'db')) ? "_".$ARGS->{authen} : "";
    $ARGS->{proc_name} = "proc_".$ARGS->{login}."_".$ARGS->{name_role}.$proc;
	$ARGS->{table_ip}  = $ARGS->{table_name} . "_tabilet_ip";

	return;
}

sub table_proc_names {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return 3205 unless $ARGS->{login};
	$ARGS->{table_name} =  "tabilet_login_".$ARGS->{name_role};

	return $self->proc_name();
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

sub check_password {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return [3100, $ARGS->{login} . " has wrong format: 4-10 letter from a-z0-9, lower case only, and starting with a letter!"] unless ($ARGS->{login} =~ /^[a-z][a-z0-9]+$/);
	return 3101 if (length($ARGS->{login})<3 or length($ARGS->{login})>10);
	if ($ARGS->{passwd}) {
		return 3102 unless ($ARGS->{passwd} eq $ARGS->{confirmpass});
		delete $ARGS->{confirmpass};
		return 3123 unless ($ARGS->{passwd} =~ /\d/ && $ARGS->{passwd} =~ /[a-zA-Z]/);
		return 3124 unless ( length($ARGS->{passwd})>=6 );
		$ARGS->{passwd} = sha1_hex($ARGS->{login}.$ARGS->{passwd});
	}
	return;
}

1;
