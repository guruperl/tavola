package Tabilet::Schema::MySQLTable;

use strict;

sub get_all_mysql {
	my $self = shift;

	my $lists = $self->{DBH}->selectall_arrayref(
"SELECT A.REFERENCED_TABLE_SCHEMA AS PKTABLE_SCHEM,
       A.REFERENCED_TABLE_NAME AS PKTABLE_NAME,
       A.REFERENCED_COLUMN_NAME AS PKCOLUMN_NAME,
       A.TABLE_CATALOG AS FKTABLE_CAT,
       A.TABLE_SCHEMA AS FKTABLE_SCHEM,
       A.TABLE_NAME AS FKTABLE_NAME,
       A.COLUMN_NAME AS FKCOLUMN_NAME,
       A.ORDINAL_POSITION AS KEY_SEQ,
       A.CONSTRAINT_NAME AS FK_NAME
  FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE A,
       INFORMATION_SCHEMA.TABLE_CONSTRAINTS B
 WHERE A.TABLE_SCHEMA = B.TABLE_SCHEMA AND A.TABLE_NAME = B.TABLE_NAME
   AND A.CONSTRAINT_NAME = B.CONSTRAINT_NAME AND B.CONSTRAINT_TYPE IS NOT NULL
   AND A.TABLE_SCHEMA = ?", {Slice=>{}}, $self->{DBNAME});

	my $ref_pk = {};
	my $ref_fk = {};
	foreach my $hash (@$lists) {
		if ($hash->{FK_NAME} eq 'PRIMARY') {
			$ref_pk->{$hash->{FKTABLE_NAME}} = $hash->{FKCOLUMN_NAME};	
		} elsif ($hash->{PKTABLE_NAME} and $hash->{PKCOLUMN_NAME}) {
			push @{$ref_fk->{$hash->{FKTABLE_NAME}}}, {
			FKCOLUMN_NAME => $hash->{FKCOLUMN_NAME},
			PKTABLE_NAME  => $hash->{PKTABLE_NAME},
			PKCOLUMN_NAME => $hash->{PKCOLUMN_NAME}};
		}
	}

	$lists = $self->{DBH}->selectall_arrayref(
"SELECT TABLE_CATALOG AS TABLE_CAT,
       TABLE_SCHEMA AS TABLE_SCHEM,
       TABLE_NAME AS TABLE_NAME,
       NON_UNIQUE AS NON_UNIQUE,
       INDEX_NAME AS INDEX_NAME,
       LCASE(INDEX_TYPE) AS TYPE,
       SEQ_IN_INDEX AS ORDINAL_POSITION,
       COLUMN_NAME AS COLUMN_NAME,
       COLLATION AS ASC_OR_DESC,
       CARDINALITY AS CARDINALITY
  FROM INFORMATION_SCHEMA.STATISTICS
 WHERE TABLE_SCHEMA = ?", {Slice=>{}}, $self->{DBNAME});
	my $ref_unique = {};
	foreach my $hash (@$lists) {
		next if $hash->{NON_UNIQUE};
		next if ($hash->{COLUMN_NAME} eq $ref_pk->{$hash->{TABLE_NAME}});
		push @{$ref_unique->{$hash->{TABLE_NAME}}}, {
			INDEX_NAME  => $hash->{INDEX_NAME},
			COLUMN_NAME => $hash->{COLUMN_NAME},
			ORDINAL_POSITION => $hash->{ORDINAL_POSITION}};
	}

	return ($ref_pk, $ref_fk, $ref_unique);
}

sub topics_mysql {
	my $self = shift;

	$self->{LISTS} = [];
	my $sth = $self->{DBH}->table_info('', $self->{DBNAME}, '%');
	while (my $hash = $sth->fetchrow_hashref()) {
		my $lists = [];
		my $err = $self->select_sql($lists,
"SHOW CREATE TABLE ".$hash->{TABLE_NAME});
		return $err if $err;	
		$hash->{create_table} = $lists->[0]->{"Create Table"};
		push @{$self->{LISTS}}, $hash;
	}
	$sth->finish;
	return;
}

sub edit_mysql {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	# Field Type Null Key Default Extra
	my $lists = $self->{DBH}->selectall_arrayref("DESCRIBE " . $self->{DBNAME} . "." . $ARGS->{table_name}, {Slice=>{}});
	my (@insert, @edit, @update, @topics, @nons);
	for my $item (@$lists) {
		push @{$self->{LISTS}}, {
			COLUMN_NAME => $item->{Field},
			TYPE        => $item->{Type},
			DEFAULTS    => $item->{Default},
			IS_NULLABLE => ($item->{Null} eq 'YES') ? 1 : 0,
			KEY         => $item->{Key},
			IS_AUTO_KEY => ($item->{Extra} eq 'auto_increment') ? 1 : 0};
		if ($item->{Extra} eq 'auto_increment') {
			$ARGS->{current_id_auto} =  $item->{Field};
			push @edit,   $item->{Field};
			push @update, $item->{Field};
			push @topics, $item->{Field};
			next;
		} elsif ($item->{Type} eq "timestamp" and $item->{Default} eq "CURRENT_TIMESTAMP") {
			push @edit,   $item->{Field};
			#push @insert, $item->{COLUMN_NAME};
			push @topics, $item->{Field};
			next;
		}
		push(@nons,   $item->{Field}) if ($item->{Null} eq 'NO');
		push @insert, $item->{Field};
		push @edit,   $item->{Field};
		push @update, $item->{Field};
		push @topics, $item->{Field};
	}
	$ARGS->{edit_pars}   = a2j(@edit);
	$ARGS->{insert_pars} = a2j(@insert);
	$ARGS->{update_pars} = a2j(@update);
	$ARGS->{topics_pars} = a2j(@topics);
	$ARGS->{nons} = \@nons if scalar(@nons);

	my $lists = [];
	my $err = $self->select_sql($lists,
"SHOW CREATE TABLE ".$ARGS->{table_name});
	return $err if $err;	
	$ARGS->{statement} = $lists->[0]->{"Create Table"};

	unless ($ARGS->{fast_mysql}) {
		$ARGS->{current_key}  = $self->get_pk(undef, $self->{DBNAME}, $ARGS->{table_name})->[0];
		$ARGS->{fks} = $self->get_fks(undef, $self->{DBNAME}, $ARGS->{table_name});
		$ARGS->{uniques} = $self->get_uniques(undef, $self->{DBNAME}, $ARGS->{table_name});
	}

	return;
}

sub a2j {
	return '["'.join('","',@_).'"]';
}

sub set_mysql_tables {
  my $self  = shift;
  my ($report, $authen) = @_;

  my $dbh  = $self->{DBH};
  my $ARGS = $self->{ARGS};
  my $name = $ARGS->{admin_user};
  my $pass = $ARGS->{admin_pass};

  my $table_name  = $ARGS->{table_name};
  my $table_ip    = $ARGS->{table_ip};
  my $proc_name   = $ARGS->{proc_name};
  my $field_id    = $ARGS->{field_id};
  my $field_login = $ARGS->{field_login};
  my $field_passwd= $ARGS->{field_passwd};
  my $field_firstname= $ARGS->{field_firstname};
  my $field_lastname= $ARGS->{field_lastname};

  if ($ARGS->{is_auto}) {
	my $str = qq~CREATE TABLE IF NOT EXISTS $table_name (
  $field_id int unsigned not null auto_increment,
  $field_login varchar(32) NOT NULL DEFAULT '',
  $field_passwd varchar(40) NOT NULL DEFAULT '',
  $field_firstname varchar(255) DEFAULT NULL,
  $field_lastname varchar(255) DEFAULT NULL,
  status enum('Yes','No') DEFAULT 'Yes',
  created datetime DEFAULT NULL,
  PRIMARY KEY ($field_id),
  UNIQUE KEY $field_login ($field_login(16))
) ENGINE=InnoDB DEFAULT CHARSET=utf8~;
	my @add = ($field_login, $field_firstname, $field_lastname, "status", "created");
    push @{$report->{tb}}, {insert_pars=>a2j(@add, $field_passwd), topics_pars=>a2j(@add, $field_id), edit_pars=>a2j(@add, $field_id), update_pars=>a2j(@add, $field_id), is_login=>1, is_tabilet=>1, current_key=>$field_id, current_id_auto=>$field_id, statement=>$str, table_name=>$table_name, projectid=>$ARGS->{projectid}, table_comment=>'Generated By Tabilet', created=>$ARGS->{created}};

	my $ret = $dbh->do(
qq~DROP TABLE IF EXISTS $table_name~) and $dbh->do($str);
    return $dbh->errstr unless $ret;
    if ($name && $pass && ($ARGS->{ds} eq 'online')) {
	  my $str = qq~INSERT INTO $table_name ($field_login, $field_passwd) VALUES (?,SHA1(concat(?, ?)))~;
      my $ret = $dbh->do($str, undef, $name, $name, $pass);
      return $dbh->errstr unless $ret;
    }

    $ARGS->{restriction} = qq~status IN ("Yes")
AND $field_login =i_login
AND $field_passwd=SHA1(concat(i_login, i_passwd))~;
  }
  my $restriction = $ARGS->{restriction};

  my $str_t = qq~CREATE TABLE IF NOT EXISTS $table_ip (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  ip int(10) unsigned NOT NULL,
  login VARCHAR(255) NOT NULL,
  updated timestamp,
  ret enum('fail','success') NOT NULL DEFAULT 'fail',
  PRIMARY KEY (id),
  KEY updated (updated),
  KEY ip (ip)
) ENGINE=InnoDB DEFAULT CHARSET=utf8~;

  my $str_p = qq~CREATE PROCEDURE $proc_name (
IN i_login VARCHAR(255), IN i_passwd VARCHAR(255), IN i_ip INT unsigned,
OUT out_id INT unsigned, OUT out_login VARCHAR(255),
OUT out_firstname varchar(255), OUT out_lastname VARCHAR(255))
BEGIN
  DECLARE c1 INT;
  DECLARE c2 INT;
  SELECT COUNT(*) INTO c1 FROM $table_ip WHERE ret='fail' AND ip=i_ip AND login=i_login AND (UNIX_TIMESTAMP(updated) >= (UNIX_TIMESTAMP(NOW())-3600));
  SELECT COUNT(*) INTO c2 FROM $table_ip WHERE ret='fail' AND ip=i_ip AND (UNIX_TIMESTAMP(updated) >= (UNIX_TIMESTAMP(NOW())-24*3600));
  IF (c1<=5 AND c2<=20) THEN
    SELECT $field_id, $field_login, $field_firstname, $field_lastname INTO out_id, out_login, out_firstname, out_lastname
    FROM $table_name
    WHERE $restriction;

    IF ISNULL(out_id) THEN
      INSERT INTO $table_ip (ip,login,ret) VALUES (i_ip,i_login,'fail');
    ELSE
      DELETE FROM $table_ip WHERE ret='fail' AND ip=i_ip AND (UNIX_TIMESTAMP(updated) >= (UNIX_TIMESTAMP(NOW())-24*3600));
      INSERT INTO $table_ip (ip,login,ret) VALUES (i_ip,i_login,'success');
    END IF;
  ELSE
    SELECT '1030' INTO out_id;
  END IF;
END~;

  push @{$report->{tb}}, {statement=>$str_t,     table_name=>$table_ip,  projectid=>$ARGS->{projectid}, created=>$ARGS->{created}, is_tabilet=>1, current_key=>"id", current_id_auto=>"id", is_login=>0,  topics_pars=>'["id","ip","login","updated","ret"]', edit_pars=>'["id","ip","login","updated","ret"]', update_pars=>'["id","ret"]', table_comment=>"security table for $table_name"};
  push @{$report->{sp}}, {statement=>$str_p, procedure_name=>$proc_name, projectid=>$ARGS->{projectid}, created=>$ARGS->{created}, is_tabilet=>1};

  my $ret = $dbh->do(
qq~DROP TABLE IF EXISTS $table_ip~) and $dbh->do(
qq~DROP PROCEDURE IF EXISTS $proc_name~) and $dbh->do(
$str_t) and $dbh->do(
$str_p);

  return $dbh->errstr;
}

1;
