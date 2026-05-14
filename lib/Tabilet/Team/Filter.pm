package Tabilet::Team::Filter;

use strict;
use Genelet::Utils;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub preset {
	my $self = shift;
	my $err  = $self->SUPER::preset(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	if ($who eq 'member') {
		return 3111 if ($ARGS->{m_type} eq '1' or $ARGS->{m_type} eq '4');
		return 3113 unless (($ARGS->{m_groupid} eq $ARGS->{memberid}) || ($action eq 'loginas'));
		$ARGS->{login_orig} = $ARGS->{login};
		if ($ARGS->{group_login}) {
			$ARGS->{login} = $ARGS->{group_login};
		} else {
			delete $ARGS->{login};
		}
		$ARGS->{memberid_orig} = $ARGS->{memberid};
		if ($ARGS->{group_memberid}) {
			$ARGS->{memberid} = $ARGS->{group_memberid};
		} else {
			delete $ARGS->{memberid};
		}
		$ARGS->{groupid} = $ARGS->{m_groupid};
	}

	if ($who eq 'member' && $action eq 'insert') {
		$err = $self->check_password() and return $err;
		$ARGS->{active} = 'Yes';
		$ARGS->{typeid} = $ARGS->{m_type};
	} elsif ($who eq 'member' && $action eq 'update') {
		foreach my $key (keys %$ARGS) {
			delete $ARGS->{$key} if (grep {$key eq $_} qw(passwd active type_id created ip paycard));
		}
	} elsif ($who eq 'member' && $action eq 'delete') {
		return 3118 if ($ARGS->{group_memberid} eq $ARGS->{groupid});
	} elsif ($action eq 'reset_pass' && $action eq 'change_pass') {
		return 3102 unless ($ARGS->{newpasswd} eq $ARGS->{confirm});
		delete $ARGS->{confirm};
	}

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

	my ($form, $extra, $nextextras) = @_;

	if ($action eq 'topics') {
		$extra->{groupid} = $ARGS->{memberid_orig};
	} elsif ($action eq 'insert') {
		$err = $form->check_totals($ARGS->{memberid_orig}) ||
			$form->existing("login", $ARGS->{login}, "member") ||
			$form->randomid([100000,900000], 10, "memberid", "member");
		return 3112 if ($ARGS->{total_existing} >= $ARGS->{total_account});
		return $err if $err;
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

	if ($who eq 'member') {
		$ARGS->{login} = $ARGS->{login_orig};
		$ARGS->{memberid} = $ARGS->{memberid_orig};
	}

	if ($action eq 'topics') {
		$err = $form->check_totals($ARGS->{memberid}) and return $err;
	} elsif ($who eq 'member' and $action eq 'loginas') {
		$form->{OTHER}->{loginas} = {
			Role  => 'member',
			Provider=>"db",
			Uri   => 'project?action=topics',
			Login => $ARGS->{Login},
			Extra => {m_isgroup=>1, groupid=>$ARGS->{groupid}},
		}
	}

	return;
}

1;
