package Tabilet::Nextpage::Filter;

use strict;
use DBI;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub fks {
	my $self = shift;
	return $self->SUPER::fks(@_) if @_;

	return {member=>["memberid",undef,"componentid","componentmd5"]}
		if ($self->{ARGS}->{g_action} eq 'topics' || $self->{ARGS}->{g_action} eq 'insert');

	return $self->SUPER::fks();
}

sub preset {
	my $self = shift;
	my $err  = $self->SUPER::preset(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};
	my $memberid = $ARGS->{memberid};

	return;
}

sub before {
	my $self = shift;
	my $err  = $self->SUPER::before(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	my ($form, $extra, $nextextras, $onceextras) = @_;
	if ($action eq 'topics') {
		$onceextras->[0]->{projectid} = $ARGS->{projectid};
	}

	return;
}

sub after {
	my $self = shift;
	my $err  = $self->SUPER::after(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

    my ($form) = @_;
    my $lists = $form->{LISTS};
    my $other = $form->{OTHER};

	return;
}

1;
