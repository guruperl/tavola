package Tabilet::Team::Model;

use strict;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub loginas {
	my $self = shift;
	my $extra = shift;

	my $ARGS = $self->{ARGS};

	my $err = $self->get_args($ARGS,
"SELECT login AS Login
FROM member
WHERE groupid=? AND memberid=?", $ARGS->{groupid}, $ARGS->{memberid});
	return 1031 unless $ARGS->{Login};
	return;
}

sub delete {
	my $self = shift;
	my $extra = shift;

	my $err = $self->get_args($self->{ARGS},
"SELECT projectid
FROM user_project
WHERE memberid=?", $self->properValue("memberid", $extra));
	return $err if $err;
	return [3112, "Account has project."] if $self->{ARGS}->{projectid};

	return $self->SUPER::delete($extra, @_);
}

sub check_totals {
	my $self = shift;
	my $id = shift;
	my $ARGS = $self->{ARGS};

	return $self->get_totals($id) || $self->get_args($ARGS,
"SELECT COUNT(*) AS total_existing
FROM member
WHERE groupid=?
AND active IN ('Yes')", $id);
}

sub get_totals {
	my $self = shift;
	my $id = shift;

	return $self->get_args($self->{ARGS},
"SELECT total_role, total_account
FROM member m
INNER JOIN def_type t USING (typeid)
WHERE memberid=?", $id);
}

1;
