package Tabilet::Role::Filter;

use strict;
use Tabilet::Filter;
use Tabilet::Generator::Config;
use Tabilet::Schema;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub fks {
	my $self = shift;
	return $self->SUPER::fks(@_) if @_;

	my $ARGS = $self->{ARGS};
	return {member=>["memberid",undef,"roleid","rolemd5"]}
		if ($ARGS->{g_action} eq 'topics' || $ARGS->{g_action} eq 'startnew');

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

	if ($action eq 'insert') {
		return 3204 if ($ARGS->{name_role} eq 'p');
		return 3201 unless ($ARGS->{name_role} =~ /^[a-z][a-z0-9]*$/);
		return 3202 if (length($ARGS->{name_role}) > 10);
		my $pre = "login";
		if ($ARGS->{authen} eq 'facebook' || $ARGS->{authen} eq 'google' || $ARGS->{authen} eq 'zoom') {
			$pre = $ARGS->{authen};
			$ARGS->{is_auto} = 1;
		}
		if ($ARGS->{is_auto}) {
			$ARGS->{field_id} = $ARGS->{name_role}."_id";
			$ARGS->{field_login} = "email";
			$ARGS->{field_passwd} = "passwd";
			$ARGS->{field_firstname} = "firstname";
			$ARGS->{field_lastname} = "lastname";
			$err = $self->table_proc_names() and return $err;
		} else {
			return 3203 unless $ARGS->{tableid};
		}
	} elsif ($who eq 'member' and $action eq 'delete') {
		return [3207, "Built-in admin role can't be deleted."] if ($ARGS->{name_role} eq 'a');
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

    my ($form, $extra, $nextextras, $onceextras) = @_;

    if ($action eq 'topics' or $action eq 'startnew') {
        $onceextras->[0] = {projectid=>$ARGS->{projectid}};
    } elsif ($action eq 'insert') {
		unless ($ARGS->{is_auto}) {
			$err = $form->get_args($ARGS,
"SELECT table_name FROM user_table WHERE tableid=?", $ARGS->{tableid})
			|| $self->proc_name();
			return $err if $err;
		}
		my $schema = Tabilet::Schema->new(args=>$ARGS, logger=>$self->{LOGGER});
		my $ref = {};
		$err = $schema->set_dbh($form) || $schema->set_login_tables($ref, $ARGS->{authen});
		$schema->{DBH}->disconnect;
		return $err if $err;
		$err = $form->insert_creation($ref) and return $err;
	} elsif ($action eq 'delete') {
		$err = $form->get_args($ARGS,
"SELECT name_role, is_admin, authen, is_auto, t.table_name, t.tableid
FROM user_role r
INNER JOIN user_table t USING (tableid)
WHERE r.roleid=?", $ARGS->{roleid}) || $self->proc_name();
		return $err if $err;
		$err = ($ARGS->{is_admin}) ? $self->table_proc_names() : $self->proc_name();
		return $err if $err;
		my $schema = Tabilet::Schema->new(args=>$ARGS, logger=>$self->{LOGGER});
		$err = $schema->set_dbh($form) || $schema->delete_login_tables();
		$schema->{DBH}->disconnect;
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
    my $other = $form->{OTHER};

	if ($action eq 'insert' || $action eq 'delete') {
		$err = $form->make_config() and return $err;
	} elsif ($action eq 'topics') {
		$_->{restriction} =~ s/"/&quot;/g for @$lists;
	}

	return;
}

1;
