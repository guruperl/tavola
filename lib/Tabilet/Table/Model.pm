package Tabilet::Table::Model;

use strict;
use Tabilet::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('Tabilet::Model');

sub simple_topics {
	my $self = shift;
	my $extra = shift;

	$self->{LISTS} = [];
	$self->select_sql($self->{LISTS},
"SELECT t.tableid, t.current_key, t.table_name, t.statement, r.name_role,
	DATE_FORMAT(t.created, '%b %d') AS created, c.name_component, 
	IF(SUBSTR(t.table_name,-11,11)='_tabilet_ip',
		SUBSTR(t.table_name,15,LENGTH(t.table_name)-25), NULL) AS name_ip
FROM user_table t
LEFT JOIN user_role r ON (t.tableid=r.tableid)
LEFT JOIN user_component c ON (t.tableid=c.tableid)
WHERE t.projectid=?", $self->{ARGS}->{projectid});
}

sub insert {
	my $self = shift;
	my $extra = shift;

	my $err = $self->SUPER::insert($extra);
	return $err if $err;
	my $id = $self->{LISTS}->[0]->{tableid};

	if ($extra->{fks}) {
		for my $item (@{$extra->{fks}}) {
			$item->{tableid} = $id;
			$err = $self->call_once({model=>"fktable",action=>"insert"}, $item);
			return $err if $err;
		}
	}		

	if ($extra->{uniques}) {
		for my $item (@{$extra->{uniques}}) {
			$item->{tableid} = $id;
			$err = $self->call_once({model=>"uniquetable",action=>"insert"}, $item);
			return $err if $err;
		}
	}		

	if ($extra->{nons}) {
		for my $item (@{$extra->{nons}}) {
			$err = $self->call_once({model=>"nontable",action=>"insert"}, {COLUMN_NAME=>$item, tableid=>$id});
			return $err if $err;
		}
	}

	return;
}

1;
