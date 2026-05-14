package Tabilet::Project::Model;

use strict;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub get_github {
	my $self = shift;
	my $hash = shift;

	return $self->get_args($hash,
"SELECT login AS git_login, access_token
FROM mem_github
WHERE memberid=?", $self->{ARGS}->{memberid});
}

sub get_tabilet_tables {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	$ARGS->{tabilet_tables} = [];
	$ARGS->{tabilet_procedures} = [];
	return $self->select_sql($ARGS->{tabilet_tables},
"SELECT table_name
FROM user_table
WHERE is_tabilet>0 AND projectid=?", $ARGS->{projectid}) ||
	$self->select_sql($ARGS->{tabilet_procedures},
"SELECT procedure_name
FROM user_procedure
WHERE is_tabilet>0 AND projectid=?", $ARGS->{projectid});
}

sub xgit {
	my $self = shift;
	return $self->edit(@_);
}
	
sub xerase {
	my $self = shift;
	return $self->startnew(@_);
}

sub get_subscription {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->get_args($ARGS,
"SELECT IF(subscription_type!='', subscription_type, 'NONE') AS subscription_type, (now()-subscription_time) AS ago, biller_id AS plan_id
FROM member m
INNER JOIN def_plan p ON (m.typeid=p.typeid AND p.is_default='Yes')
WHERE m.memberid=?", $ARGS->{memberid});
}

sub upd_config {
	my $self = shift;
	my ($json, $filter, $model) = @_;

	return $self->do_sql(
"UPDATE user_project SET config_json=?, filter=?, model=?
WHERE projectid=?", $json, $filter, $model, $self->{ARGS}->{projectid});
}

sub startnew {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	$self->{LISTS} = [];
	
	my $err = $self->select_sql($self->{LISTS},
"SELECT p.projectid, p.Project, g.login AS git_login
FROM user_project p
LEFT JOIN mem_github g USING (memberid)
WHERE p.memberid=?", $ARGS->{memberid});
	return $err if $err;
	$ARGS->{git_login} = $self->{LISTS}->[0]->{git_login};

	return;
}

sub landing_pages {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	
	my $p_list = [];
	my $a_list = [];
	my $r_list = [];
	my $err = $self->get_args($ARGS,
"SELECT projectid, def_component, def_action
FROM user_project
WHERE memberid=?", $ARGS->{memberid}) || $self->select_sql($p_list,
"SELECT name_component, action
FROM view_landing_p
WHERE projectid=?", $ARGS->{projectid}) || $self->get_args($ARGS,
"SELECT roleid AS aroleid, default_component, default_action
FROM user_role
WHERE name_role='a'
AND projectid=?", $ARGS->{projectid}) || $self->select_sql($a_list,
"SELECT name_component
FROM user_component
WHERE projectid=?", $ARGS->{projectid}) || $self->select_sql($r_list,
"SELECT r.roleid, r.name_role, default_component, default_action,
	name_component, level, action, is_edit, is_topics, is_startnew
FROM user_role r
LEFT JOIN view_landing v USING (roleid)
WHERE r.projectid=? AND r.name_role!='a'
ORDER BY v.componentid, v.level", $ARGS->{projectid});
	return $err if $err;

	my $missing = [];
	push(@$missing, "Public's default component or action") unless ($ARGS->{def_component} && $ARGS->{def_action});
	push(@$missing, "Admin's default component or action") unless ($ARGS->{default_component} && $ARGS->{default_action});
	for my $item (@$r_list) {
		push(@$missing, $item->{name_role} . "'s default component or action") unless ($item->{default_component} && $item->{default_action});
	}
		
	$self->{OTHER}->{p_list} = $p_list;	
	$self->{OTHER}->{a_list} = $a_list;	
	$self->{OTHER}->{r_list} = $r_list;	
	$self->{OTHER}->{missing} = $missing;	

	return;
}

=pod
sub set_p {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->do_sql(
"UPDATE user_project SET def_component=?, def_action=?
WHERE projectid=?", map {$ARGS->{$_}} qw(def_component def_action projectid));
}

sub query_p {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $hash = {};
	my $err = $self->get_args($hash,
"SELECT crud FROM user_action_public
INNER JOIN user_component USING (componentid)
WHERE projectid=? AND name_component=?", $ARGS->{projectid}, $ARGS->{def_component});
	return $err if $err;
	$self->{LISTS} = [];
	for (split(',', $hash->{crud}, -1)) {
		if (($ARGS->{is_tabilet} && $_ eq 'edit') or ($_ eq 'startnew') or ($_ eq 'topics')) {
			push(@{$self->{LISTS}}, {crud=>$_});
		}
	}
	return;	
}

sub reset_p {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->do_sql(
"UPDATE user_project SET def_component=NULL, def_action=NULL
WHERE projectid=?", $ARGS->{projectid});
}

sub set_r {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->do_sql(
"UPDATE user_role SET default_component=?, default_action=?
WHERE projectid=? AND roleid=?", map {$ARGS->{$_}} qw(default_component default_action projectid roleid));
}

sub query_r {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT is_edit, is_startnew, is_topics FROM view_landing
WHERE projectid=? AND roleid=? AND name_component=?", map {$ARGS->{$_}} qw(projectid roleid default_component));
}

sub reset_r {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->do_sql(
"UPDATE user_role SET default_component=NULL, default_action=NULL
WHERE projectid=? AND roleid=?", $ARGS->{projectid}, $ARGS->{roleid});
}
=cut

1;
