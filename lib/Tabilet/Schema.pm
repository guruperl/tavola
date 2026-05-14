package Tabilet::Schema;

use strict;
use Storable qw(dclone);
use Data::Dumper;
use Genelet::DBI;

use Tabilet::Schema::MySQLGoogle;
use Tabilet::Schema::MySQLZoom;
use Tabilet::Schema::MySQLFacebook;
use Tabilet::Schema::MySQLTable;
use Tabilet::Schema::PostgresGoogle;
use Tabilet::Schema::PostgresZoom;
use Tabilet::Schema::PostgresFacebook;
use Tabilet::Schema::PostgresTable;

use vars qw(@ISA);
@ISA = (qw(Genelet::DBI Tabilet::Schema::MySQLZoom Tabilet::Schema::PostgresZoom Tabilet::Schema::MySQLFacebook Tabilet::Schema::MySQLTable Tabilet::Schema::MySQLGoogle Tabilet::Schema::PostgresGoogle Tabilet::Schema::PostgresFacebook Tabilet::Schema::PostgresTable));

__PACKAGE__->setup_accessors(
	args   => undef, 
	lists  => undef,
	logger => undef,

	dbname => "",
	host   => "",
	port   => "",
	dbtype => "",
	dbuser => "",
	dbpass => ""
);

sub is_identifier {
	my $value = shift;
	return defined($value) && $value =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/ && length($value) <= 64;
}

sub quote_identifier {
	my $self = shift;
	my $value = shift;
	return unless is_identifier($value);
	return $self->{DBH}->quote_identifier($value) if $self->{DBH};
	return $value;
}

sub set_dbh {
	my $self = shift;
	my $form = shift || return 1079; # standard model with normal db handler
	my $ARGS = $self->{ARGS};

	my $find = 1;
	for (qw(dbname host port dbtype dbuser dbpass)) {
		unless ($ARGS->{$_}) {
			$find = 0;
			last;
		}
	}
	if ($find) {
		for (qw(dbname host port dbtype dbuser dbpass)) {
			$self->{uc $_} = $ARGS->{$_};
		}
	} else {
		my $err = $form->call_once({model=>"ds", action=>"topics"}, {projectid=>$ARGS->{projectid}});
		return $err if $err;
		for (qw(dbname host port dbtype dbuser dbpass)) {
			$self->{uc $_} = $form->{OTHER}->{ds_topics}->[0]->{$_};
		}
	}
	
	return $self->_set_dbh();
}

sub _set_dbh {
	my $self = shift;

	my $ds = "dbi";
	if ($self->{DBTYPE} eq 'PostgreSQL') {
		$ds .= ":Pg:database=".$self->{DBNAME};
	} elsif ($self->{DBTYPE} eq 'MySQL') {
		$ds .= ":mysql:database=";
		$ds .= $self->{DBNAME} unless ($self->{DBNAME} eq 'postgres');
	}
	$ds .= ";host=".$self->{HOST}.";port=".$self->{PORT};
	$ds .= ";mysql_multi_statements=1" if ($self->{DBTYPE} eq 'MySQL');
	$self->{LOGGER}->info("Data source connection string: $ds USING " . $self->{DBUSER});
	$self->{DBH} = DBI->connect($ds, $self->{DBUSER}, $self->{DBPASS}) or return 1072;
	return;
}

sub delete {
	my $self = shift;
	my $table = $self->quote_identifier($self->{ARGS}->{table_name}) or return 3203;

	my $rows = $self->{DBH}->do(
"DROP TABLE IF EXISTS ".$table);
	return $self->{DBH}->errstr;
}

sub insert {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $rows = $self->{DBH}->do($ARGS->{statement});
	return $self->{DBH}->errstr;
}
 
sub topics {
	my $self = shift;

	return $self->topics_postgres() if ($self->{DBTYPE} eq 'PostgreSQL');
	return $self->topics_mysql();
}

sub edit {
	my $self = shift;

	return $self->edit_postgres() if ($self->{DBTYPE} eq 'PostgreSQL');
	return $self->edit_mysql();
}

# mysql: undef, $self->{DBNAME}, $ARGS->{table_name}
# pg: $self->{DBNAME}, 'public', $ARGS->{table_name}
sub get_pk {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my @PKS = qw(
TABLE_CAT TABLE_SCHEM TABLE_NAME COLUMN_NAME KEY_SEQ PK_NAME);
	my $sth = $self->{DBH}->primary_key_info(@_);
	if ($sth) {
		my $lists = $sth->fetchall_arrayref;
		my %ref;
		for my $arr (@$lists) {
			$ref{$arr->[4]} = $arr->[3];
			$ARGS->{$arr->[2]}->{current_index_name} = $arr->[5];
		}
		return [map {$ref{$_}} (sort keys %ref)];
	}
	return;
}

# mysql: undef, $self->{DBNAME}, $ARGS->{table_name}
# pg: $self->{DBNAME}, 'public', $ARGS->{table_name}
sub get_fks {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my @FKS = qw(
PKTABLE_CAT   PKTABLE_SCHEM PKTABLE_NAME  PKCOLUMN_NAME FKTABLE_CAT
FKTABLE_SCHEM FKTABLE_NAME  FKCOLUMN_NAME KEY_SEQ       UPDATE_RULE
DELETE_RULE   FK_NAME       PK_NAME       DEFERRABILITY UNIQUE_OR_PRIMARY
UK_DATA_TYPE  FK_DATA_TYPE);

	my $sth = $self->{DBH}->foreign_key_info( undef, undef, undef, @_);
	if ($sth) {
		my $lists = $sth->fetchall_arrayref;
		my @fks;
		for my $arr (@$lists) {
			next if ($arr->[11] eq 'PRIMARY');
			next unless ($arr->[2] && $arr->[3]); # mysql returns even no t & c
			push @fks, {$FKS[7]=>$arr->[7], $FKS[2]=>$arr->[2], $FKS[3]=>$arr->[3]};
		}
		return [@fks] if scalar(@fks);
	}
	return;
}

# mysql: undef, $self->{DBNAME}, $ARGS->{table_name}
# pg: $self->{DBNAME}, 'public', $ARGS->{table_name}
sub get_uniques {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my @UNIQUES = qw(
TABLE_CAT   TABLE_SCHEM TABLE_NAME       NON_UNIQUE  INDEX_QUALIFIER
INDEX_NAME  TYPE        ORDINAL_POSITION COLUMN_NAME ASC_OR_DESC
CARDINALITY PAGES       FILTER_CONDITION);

	my $sth = $self->{DBH}->statistics_info(@_, 1, 0);
	if ($sth) {
		my $lists = $sth->fetchall_arrayref;
		my @uniques;
		for my $arr (@$lists) {
			next if ($ARGS->{$arr->[2]}->{current_index_name} eq $arr->[5]);
			next if $arr->[3]; # 0 is unique, 1 means not unique
			push @uniques, {$UNIQUES[5]=>$arr->[5], $UNIQUES[7]=>$arr->[7], $UNIQUES[8]=>$arr->[8]};
		}
		return [@uniques] if scalar(@uniques);
	}
	return;
}

sub delete_login_tables {
  my $self  = shift;

  my $dbh  = $self->{DBH};
  my $ARGS = $self->{ARGS};

  my $table_name = $ARGS->{table_name};
  my $table_ip   = $ARGS->{table_ip};
  my $proc_name  = $ARGS->{proc_name};

  my $ret = $dbh->do(
qq~DROP PROCEDURE IF EXISTS $proc_name~) and $dbh->do(
qq~DROP TABLE IF EXISTS $table_ip~);
  return $dbh->errstr if $dbh->errstr;
  if ($ARGS->{is_auto}) {
    $ret = $dbh->do(
qq~DROP TABLE IF EXISTS $table_name~);
    return $dbh->errstr if $dbh->errstr;
  }
  return;
}

sub drop_tabilet_tables {
  my $self  = shift;
  my $dbh  = $self->{DBH};
  my $ARGS = $self->{ARGS};

  if ($self->{DBTYPE} eq 'PostgreSQL') {
    my $ret = $self->do_sql(
qq~DROP FUNCTION IF EXISTS tabilet_create_statement(p_table_name varchar)~);
    return $dbh->errstr if $dbh->errstr;
  }

  foreach my $tb (@{$ARGS->{tabilet_tables}}) {  
    my $ret = $dbh->do(qq~DROP TABLE IF EXISTS ~.$tb->{table_name});
    return $dbh->errstr if $dbh->errstr;
  }
  foreach my $sp (@{$ARGS->{tabilet_procedures}}) {  
    my $ret = $dbh->do(qq~DROP PROCEDURE IF EXISTS ~.$sp->{procedure_name});
    return $dbh->errstr if $dbh->errstr;
  }

  return;
}

sub set_login_tables {
  my $self  = shift;
  my ($report, $authen) = @_;

  if ($self->{DBTYPE} eq 'PostgreSQL') {
    my $ret = $self->do_sql($self->create_statement());
    my $dbh  = $self->{DBH};
    return $dbh->errstr if $dbh->errstr;
    return $self->set_postgres_facebook($report) if ($authen eq 'facebook');
    return $self->set_postgres_google($report) if ($authen eq 'google');
    return $self->set_postgres_zoom($report) if ($authen eq 'zoom');
    return $self->set_postgres_tables($report);
  }
  return $self->set_mysql_facebook($report) if ($authen eq 'facebook');
  return $self->set_mysql_google($report) if ($authen eq 'google');
  return $self->set_mysql_zoom($report) if ($authen eq 'zoom');
  return $self->set_mysql_tables($report);
}

sub sync {
    my $self   = shift;
    my $form   = shift;

	my $err = $self->topics();
	return $err if $err;
	my $schema_lists = dclone($self->{LISTS});
    my $ARGS = $self->{ARGS};
	my $err = $form->call_once({model=>"table", action=>"simple_topics"}, {projectid=>$ARGS->{projectid}});
	my $lists = $form->{OTHER}->{table_simple_topics};

    my @PAR1S = qw(edit_pars insert_pars update_pars topics_pars current_id_auto current_key table_name statement);
    my @PAR2S = qw(nons);

	my ($REF_pks, $REF_fks, $REF_uniques);
	if ($ARGS->{fast_mysql}) {
		($REF_pks, $REF_fks, $REF_uniques) = $self->get_all_mysql();
	} else {
		push @PAR2S, 'fks';
		push @PAR2S, 'uniques';
	}
	my $easy = {};
    for my $dbtable (map {$_->{TABLE_NAME}} @{$schema_lists}) {
		$easy->{$dbtable} = 1;
        next if (grep {$dbtable eq $_->{table_name}} @$lists); # match found
        for (@PAR1S, @PAR2S) {
            delete($ARGS->{$_}) if defined($ARGS->{$_});
        }
# pgsql may have extra "" on name
		$ARGS->{table_name} = ($dbtable =~ /^"(.*)"$/) ? $1 : $dbtable;
        my $err = $self->edit();
		return $err if $err;
        my $ref = {};
        for (@PAR1S) {
            $ref->{$_} = $ARGS->{$_} if defined($ARGS->{$_});
        }
       	for my $var (@PAR2S) {
           	if (defined($ARGS->{$var}) and scalar(@{$ARGS->{$var}})>0) {
               	push(@{$ref->{$var}}, $_) for @{$ARGS->{$var}};
           	}
		}
		if ($ARGS->{fast_mysql}) {
			$ref->{current_key} = $REF_pks->{$dbtable};
			$ref->{fks}     = $REF_fks->{$dbtable};
			$ref->{uniques} = $REF_uniques->{$dbtable};
        }
        $err = $form->call_once({model=>"table", action=>"insert"}, $ref);
        return $err if $err;
    }

# tables not in user db will be deleted silently !!
# because user won't see them anyway.
	for my $item (@$lists) {
		unless ($easy->{$item->{table_name}}) {
			$err = $form->do_sql(
"DELETE FROM user_table WHERE tableid=?", $item->{tableid}) and return $err;
		}
	}

    return;
}

1;
