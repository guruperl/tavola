package Tabilet::Component::Model;

use strict;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub exists_column {
	my $self    = shift;
	my $column  = shift;
	my $ARGS = $self->{ARGS};
	my $json_column = $self->{DBH}->quote('"' . $column . '"');

	my $ref = {};
	my $err = $self->get_args($ref,
"SELECT 
JSON_CONTAINS(`insert_pars`, $json_column) AS p1,
JSON_CONTAINS(`edit_pars`,   $json_column) AS p2,
JSON_CONTAINS(`topics_pars`, $json_column) AS p3,
JSON_CONTAINS(`update_pars`, $json_column) AS p4
FROM user_table
WHERE tableid=?", $ARGS->{tableid});
	return $err if $err;

	$ARGS->{one} = ($ref->{p1}||$ref->{p2}||$ref->{p3}||$ref->{p4}) ? 1 : 0;
	return;
}

sub code {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT componentid, projectid, name_component, component_json, filter, model
FROM user_component
WHERE componentid=?", $ARGS->{componentid});
}

sub pub_crud {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->get_args($ARGS,
"SELECT Project, Pubrole, crud, t.table_name
FROM user_component c
INNER JOIN user_project      p USING (projectid)
LEFT JOIN user_action_public a USING (componentid)
LEFT JOIN user_table         t USING (tableid)
WHERE c.componentid=?", $ARGS->{componentid});
}

sub update_cfm {
	my $self = shift;

	return $self->do_sql(
"UPDATE user_component
SET component_json=?, filter=?, model=?
WHERE componentid=?", @_);
}

sub deal_action {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $err;
	if ($ARGS->{roles}) {
		my $old_table = $self->{CURRENT_TABLE};
		$self->current_table("user_action");
		for my $roleid (keys %{$ARGS->{roles}}) {
			my $item = $ARGS->{roles}->{$roleid};
			$item->{componentid} = $ARGS->{componentid};
			$item->{roleid} = $roleid;
			$err = $self->insert_hash($item) and return $err;
		}
		$self->current_table($old_table);
	}
	if ($ARGS->{public}) {
		$err = $self->do_sql(
"INSERT INTO user_action_public (componentid, crud)
VALUES (?,?)", $ARGS->{componentid}, $ARGS->{public}) and return $err;
	}

	return;
}

sub insert {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	my $dbh = $self->{DBH};

	my $err = $self->do_sql(
"INSERT INTO user_component (name_component, description, created, projectid, tableid, current_key, current_id_auto, insert_pars, edit_pars, update_pars, topics_pars)
SELECT ".$dbh->quote($ARGS->{name_component}).", ".$dbh->quote($ARGS->{description}).", NOW(), projectid, tableid, current_key, current_id_auto, insert_pars, edit_pars, update_pars, topics_pars
FROM user_table
WHERE tableid = ?", $ARGS->{tableid});
	return $err if $err;
	$ARGS->{componentid} = $dbh->last_insert_id(undef, $ARGS->{login}, "user_component", "componentid");
	return $self->deal_action() || $self->process_after("insert", @_);
}

sub update {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	return $self->SUPER::update(shift) ||
		$self->do_sql(
"DELETE FROM user_action WHERE componentid=?", $ARGS->{componentid}) ||
		$self->do_sql(
"DELETE FROM user_action_public WHERE componentid=?", $ARGS->{componentid}) ||
		$self->deal_action() ||
		$self->process_after("update", @_);
}

sub update_code {
	my $self = shift;
	return $self->SUPER::update(shift);
}

sub get_landing_p {
	my $self = shift;

	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT name_component, action, projectid
FROM view_landing_p
WHERE projectid=?", $self->{ARGS}->{projectid});
}
 
sub set_project_def {
	my $self = shift;

	my $err = $self->get_landing_p();
	return $err if $err;

	my $item = $self->{LISTS}->[0];

	if ($item && $item->{action}) {
		return $self->do_sql(
"UPDATE user_project
SET def_component=?, def_action=?
WHERE projectid=?", map {$item->{$_}} qw(name_component action projectid))
		|| $self->do_sql(
"UPDATE user_role
SET default_component=?, default_action='topics'
WHERE name_role='a'
AND projectid=?", map {$item->{$_}} qw(name_component projectid));
	}

	my $hash = {};

	my $err = $self->do_sql(
"UPDATE user_project
SET def_component=NULL, def_action=NULL
WHERE memberid=?", $self->{ARGS}->{memberid}) ||  $self->get_args($hash,
"SELECT name_component, p.projectid
FROM user_component c
INNER JOIN user_project p USING (projectid)
WHERE memberid=? LIMIT 1", $self->{ARGS}->{memberid});
	return $err if $err;
	if ($hash->{name_component}) {
		return $self->do_sql(
"UPDATE user_role
SET default_component=?, default_action='topics'
WHERE name_role='a'
AND projectid=?", map {$hash->{$_}} qw(name_component projectid));
	}
	return;
}

sub get_landing_r {
	my $self = shift;

	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT r.roleid, r.name_role, name_component, level, action
FROM user_role r
LEFT JOIN view_landing v USING (roleid)
WHERE r.projectid=?
AND r.name_role!='a'
ORDER BY componentid, level", $self->{ARGS}->{projectid});
}
 
sub set_role_defaults {
	my $self = shift;

	my $err = $self->get_landing_r();
	return $err if $err;

	my $ref = {};
	for my $item (@{$self->{LISTS}}) {
		next if $ref->{$item->{roleid}};
		$ref->{$item->{roleid}} = 1;
		$err = ($item->{action})
			? $self->do_sql(
"UPDATE user_role SET default_component=?, default_action=?
WHERE roleid=?", map {$item->{$_}} qw(name_component action roleid))
			: $self->do_sql(
"UPDATE user_role SET default_component=NULL, default_action=NULL
WHERE roleid=?", map {$item->{$_}} qw(roleid));
		return $err if $err;
	}

	return;
}

1;
