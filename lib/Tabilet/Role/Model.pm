package Tabilet::Role::Model;

use strict;
use Genelet::Tree;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub simple {
	my $self = shift;
	my $extra = shift;

	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT name_role, description, authen, is_admin, is_auto
FROM user_role
WHERE projectid=?", $extra->{projectid}||$self->{ARGS}->{projectid});
}

sub delete {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $err = $self->SUPER::delete(@_) || $self->do_sql(
"DELETE FROM user_table
WHERE projectid = ? AND table_name =?",
	$ARGS->{projectid}, $ARGS->{table_ip});
	return $err if $err;

	return ($ARGS->{is_auto})
		?  $self->do_sql( # will delete procedure because of ON DELETE
"DELETE FROM user_table
WHERE projectid = ?
AND table_name =?", $ARGS->{projectid}, $ARGS->{table_name})
		: $self->do_sql( # because ON DELETE is on the main table
"DELETE FROM user_procedure
WHERE projectid=?
AND tableid =?", $ARGS->{projectid}, $ARGS->{tableid});
}

sub acl {
	my $self = shift;
	my $extra = shift;
	my $ARGS = $self->{ARGS};
	my $cid = $ARGS->{componentid};

	$self->{LISTS} = [];
	return $self->get_args($ARGS,
"SELECT apid, crud
FROM user_action_public
WHERE componentid=?", $cid) || $self->select_sql($self->{LISTS},
"SELECT r.roleid, r.name_role,
	a.actionid, a.crud, a.inkey, a.inmd5, a.outkey, a.outmd5
FROM user_role r
LEFT JOIN user_action a ON (r.roleid=a.roleid AND a.componentid=?)
WHERE r.is_admin!=1 AND r.projectid=?", $cid, $ARGS->{projectid});
}

sub pub_acl {
	my $self = shift;
	my $extra = shift;
	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT crud, a.componentid,
name_component, current_key, insert_pars, edit_pars, update_pars, topics_pars
FROM user_component c
INNER JOIN user_action_public a USING (componentid)
WHERE c.projectid=?", $extra->{projectid}||$self->{ARGS}->{projectid});
}

sub role_acl {
	my $self = shift;
	my $extra = shift;
	$self->{LISTS} = [];
	return $self->select_sql($self->{LISTS},
"SELECT crud, inkey, inmd5, outkey, outmd5,
	a.componentid, a.roleid, r.name_role, r.field_id,
name_component, current_key, insert_pars, edit_pars, update_pars, topics_pars
FROM user_component c
INNER JOIN user_action a USING (componentid)
INNER JOIN user_role r USING (roleid)
WHERE c.projectid=?", $extra->{projectid}||$self->{ARGS}->{projectid});
}

sub topics_check {
    my $self = shift;
    my $ARGS = $self->{ARGS};

    my $err = $self->get_args($ARGS,
"SELECT current_key AS three, CONCAT(table_name, '__', current_key) AS fk
FROM user_table
WHERE tableid=?", $ARGS->{tableid});
    return $err if $err;

    my $roles = [];
    $err = $self->select_sql($roles,
"SELECT r.roleid, r.name_role, t.current_key, CONCAT(t.table_name, '__', t.current_key) AS fk
FROM user_role r
INNER JOIN user_table t USING (tableid)
WHERE r.projectid=? AND r.name_role != 'a'", $ARGS->{projectid});
    return $err if $err;

    my $lists = [];
    $err = $self->select_sql($lists,
"SELECT fkid, a.tableid AS fid, FKCOLUMN_NAME, t.table_name AS FKTABLE_NAME,
t.current_key, b.tableid AS pid, PKTABLE_NAME, PKCOLUMN_NAME,
CONCAT(t.table_name,'__',t.current_key) AS fk,
CONCAT(PKTABLE_NAME,'__',PKCOLUMN_NAME) AS pk
FROM user_table_fk a
INNER JOIN user_table t ON (a.tableid=t.tableid)
LEFT JOIN user_table b ON (a.PKTABLE_NAME=b.table_name)
WHERE t.projectid=? AND b.projectid=?", $ARGS->{projectid}, $ARGS->{projectid});
    return $err if $err;

    for my $role (@$roles) {
		my $ref = {};
		push(@{$ref->{$_->{fk}}}, $_) for @$lists;
        my @parents = Genelet::Tree::tree_find_parents($role->{fk}, $ref, 'pk', $ARGS->{fk});
        my $finished = $parents[scalar(@parents)-1];
        if ($finished->{_found}) {
            my $top = $parents[0];
            $role->{one} = $top->{FKCOLUMN_NAME};
        	$role->{three} = $ARGS->{three};
        }
    }

    $self->{LISTS} = $roles;
    return;
}

1;
