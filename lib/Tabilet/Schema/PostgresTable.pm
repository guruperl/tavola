package Tabilet::Schema::PostgresTable;

use strict;

sub create_statement {
	my $self = shift;
	return qq`CREATE OR REPLACE FUNCTION tabilet_create_statement(p_table_name varchar)
  RETURNS text AS
\$BODY\$
DECLARE
    v_table_ddl   text;
    column_record record;
BEGIN
    FOR column_record IN 
        SELECT b.nspname as schema_name, b.relname as table_name, a.attname as column_name, pg_catalog.format_type(a.atttypid, a.atttypmod) as column_type,
            CASE WHEN 
                (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                 FROM pg_catalog.pg_attrdef d
                 WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef) IS NOT NULL THEN
                'DEFAULT '|| (SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
                              FROM pg_catalog.pg_attrdef d
                              WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef)
            ELSE
                ''
            END as column_default_value,
            CASE WHEN a.attnotnull = true THEN 
                'NOT NULL'
            ELSE
                'NULL'
            END as column_not_null,
            a.attnum as attnum, e.max_attnum as max_attnum
        FROM 
            pg_catalog.pg_attribute a
            INNER JOIN 
             (SELECT c.oid, n.nspname, c.relname
              FROM pg_catalog.pg_class c
                   LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
              WHERE c.relname ~ ('^('||p_table_name||')\$')
                AND pg_catalog.pg_table_is_visible(c.oid)
              ORDER BY 2, 3) b
            ON a.attrelid = b.oid
            INNER JOIN 
             (SELECT a.attrelid, max(a.attnum) as max_attnum
              FROM pg_catalog.pg_attribute a
              WHERE a.attnum > 0 AND NOT a.attisdropped
              GROUP BY a.attrelid) e
            ON a.attrelid=e.attrelid
        WHERE a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum
    LOOP
        IF column_record.attnum = 1 THEN
            v_table_ddl:='CREATE TABLE '||column_record.schema_name||'.'||column_record.table_name||' (';
        ELSE
            v_table_ddl:=v_table_ddl||',';
        END IF;

        IF column_record.attnum <= column_record.max_attnum THEN
            v_table_ddl:=v_table_ddl||chr(10)||
                     '    '||column_record.column_name||' '||column_record.column_type||' '||column_record.column_default_value||' '||column_record.column_not_null;
        END IF;
    END LOOP;

    v_table_ddl:=v_table_ddl||');';
    RETURN v_table_ddl;
END;
\$BODY\$
  LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;`;
}

sub topics_postgres {
	my $self = shift;

	$self->{LISTS} = [];
	my $sth = $self->{DBH}->table_info($self->{DBNAME}, "public", "");
	while (my $hash = $sth->fetchrow_hashref()) {
		my $lists = [];
		my $err = $self->select_sql($lists,
"SELECT tabilet_create_statement('".$hash->{TABLE_NAME}."') AS cs");
		return $err if $err;
		$hash->{create_table} = $lists->[0]->{"cs"};
		push @{$self->{LISTS}}, $hash;
	}
	$sth->finish;

	return;
}

sub edit_postgres {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	$self->{LISTS} = [];

	my $sth = $self->{DBH}->column_info($self->{DBNAME}, 'public', $ARGS->{table_name}, undef);
	my $lists = $sth->fetchall_arrayref;
	my @pars = qw(
TABLE_CAT         TABLE_SCHEM      TABLE_NAME    COLUMN_NAME    DATA_TYPE
TYPE_NAME         COLUMN_SIZE      BUFFER_LENGTH DECIMAL_DIGITS NUM_PREC_RADIX
NULLABLE          REMARKS          COLUMN_DEF    SQL_DATA_TYPE  SQL_DATETIME_SUB
CHAR_OCTET_LENGTH ORDINAL_POSITION IS_NULLABLE   pg_type        pg_constraint
pg_schema         pg_table         pg_column     pg_enum_values
);
	my (@insert, @edit, @update, @topics, @nons);
	for my $arr (@$lists) {
		my $item;
		for (my $i=0; $i<scalar(@pars); $i++) {	
			$item->{$pars[$i]} = $arr->[$i];
		}
		$item->{KEY}  = ($item->{COLUMN_DEF} =~ /PRI/) ? 1 : 0;
		$item->{TYPE} = $item->{pg_type},
		$item->{IS_AUTO_KEY} = ($item->{COLUMN_DEF} =~ /nextval/) ? 1 : 0;
		$item->{DEFAULTS}    = $item->{pg_constraint};
		my $column_name = $item->{COLUMN_NAME};
		if ($column_name =~ /^"(.*)"$/) {
			$column_name = $1;
			$item->{COLUMN_NAME} = $column_name;
		}
		push @{$self->{LISTS}}, $item;
		push @edit,   $column_name;
		push @update, $column_name;
		if ($item->{COLUMN_DEF} =~ /nextval/) {
			$ARGS->{current_id_auto} =  $column_name;
			push @update, $column_name;
			next;
		} elsif ($item->{TYPE_NAME} =~ /^timestamp/) {
			push @insert, $column_name;
			next;
		}
		push(@nons,   $column_name) unless $item->{NULLABLE};
		push @insert, $column_name;
		push @update, $column_name;
	}
	$sth->finish;
	$ARGS->{edit_pars}   = a2j(@edit);
	$ARGS->{insert_pars} = a2j(@insert);
	$ARGS->{update_pars} = a2j(@update);
	$ARGS->{topics_pars} = a2j(@topics);
	$ARGS->{nons} = \@nons if scalar(@nons);

	my $err = $self->get_args($ARGS,
"SELECT tabilet_create_statement('".$ARGS->{table_name}."') AS statement");
	return $err if $err;

	my $pks = $self->get_pk($self->{DBNAME}, 'public', $ARGS->{table_name});
	$ARGS->{current_key} = $pks->[0] if ($pks);
	$ARGS->{fks}         = $self->get_fks($self->{DBNAME}, 'public', $ARGS->{table_name});
	$ARGS->{uniques} = $self->get_uniques($self->{DBNAME}, 'public', $ARGS->{table_name});

	return;
}

sub a2j {
	return '["'.join('","',@_).'"]';
}

sub set_postgres_tables {
  my $self  = shift;
  my ($report) = @_;

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
#   unless ($ARGS->{ds} eq 'online') {
#     my $ret =  $self->do_sql(
#q~CREATE EXTENSION IF NOT EXISTS pgcrypto~);
#     return $dbh->errstr unless $ret;
#   }
	my $str = qq~CREATE TABLE IF NOT EXISTS $table_name (
  $field_id SERIAL PRIMARY KEY,
  $field_login varchar(32) NOT NULL,
  $field_passwd varchar(40) NOT NULL,
  $field_firstname varchar(40) DEFAULT NULL,
  $field_lastname varchar(40) DEFAULT NULL,
  status BOOLEAN NOT NULL DEFAULT TRUE,
  created TIMESTAMP DEFAULT NOW(),
  UNIQUE ($field_login))~;
	my @add = ($field_login, $field_firstname, $field_lastname, "status", "created");
    push @{$report->{tb}}, {insert_pars=>a2j(@add, $field_passwd), topics_pars=>a2j(@add, $field_id), edit_pars=>a2j(@add, $field_id), update_pars=>a2j(@add, $field_id), is_login=>1, is_tabilet=>1, current_key=>$field_id, current_id_auto=>$field_id, statement=>$str, table_name=>$table_name, projectid=>$ARGS->{projectid}, table_comment=>'Generated By Tabilet', created=>$ARGS->{created}};

	my $ret = $dbh->do(
qq~DROP TABLE IF EXISTS $table_name~) and $dbh->do($str);
    return $dbh->errstr unless $ret;
    if ($name && $pass && ($ARGS->{ds} eq 'online')) {
	  my $str = qq~INSERT INTO $table_name ($field_login, $field_passwd) VALUES (?,encode(digest(? || ?, 'sha1'), 'hex'))~;
      my $ret = $dbh->do($str, undef, $name, $name, $pass);
      return $dbh->errstr unless $ret;
    }

    $ARGS->{restriction} = qq~status IN ("Yes")
AND $field_login =i_login
AND $field_passwd=encode(digest(i_login || i_passwd, 'sha1'), 'hex')~;
  }
  my $restriction = $ARGS->{restriction};

  my $str_t = qq~CREATE TABLE IF NOT EXISTS $table_ip (
  id SERIAL PRIMARY KEY,
  ip integer NOT NULL,
  login VARCHAR(32) NOT NULL,
  updated timestamp default current_timestamp,
  ret BOOLEAN NOT NULL DEFAULT FALSE)~;

  my $str_p = qq~CREATE PROCEDURE $proc_name (
i_login IN VARCHAR(32), i_passwd IN VARCHAR(40), i_ip IN INTEGER,
out_id INOUT INTEGER, out_login INOUT VARCHAR(32),
out_firstname INOUT varchar(40), out_lastname INOUT VARCHAR(40))
LANGUAGE plpgsql
AS \$\$
DECLARE
  c1 INTEGER;
  c2 INTEGER;
BEGIN
  SELECT COUNT(*) INTO c1 FROM $table_ip WHERE ret='fail' AND ip=i_ip AND login=i_login AND EXTRACT(EPOCH FROM (NOW()-updated)) <= 3600;
  SELECT COUNT(*) INTO c2 FROM $table_ip WHERE ret='fail' AND ip=i_ip AND EXTRACT(EPOCH FROM (NOW()-updated)) <= 24*3600;
  IF (c1<=5 AND c2<=20) THEN
    SELECT $field_id, $field_login, $field_firstname, $field_lastname INTO out_id, out_login, out_firstname, out_lastname
    FROM $table_name
    WHERE $restriction;

    IF ISNULL(out_id) THEN
      INSERT INTO $table_ip (ip,login,ret) VALUES (i_ip,i_login,'fail');
      COMMIT;
    ELSE
      DELETE FROM $table_ip WHERE ret='fail' AND ip=i_ip AND login=i_login;
      DELETE FROM $table_ip WHERE ret='fail' AND ip=i_ip AND EXTRACT(EPOCH FROM (NOW()-updated)) > 24*3600;
      INSERT INTO $table_ip (ip,login,ret) VALUES (i_ip,i_login,'success');
      COMMIT;
    END IF;
  ELSE
    SELECT '1030' INTO out_id;
  END IF;
END ;
\$\$;~;

  push @{$report->{tb}}, {statement=>$str_t,     table_name=>$table_ip,  projectid=>$ARGS->{projectid}, created=>$ARGS->{created}, is_tabilet=>1, current_key=>"id", current_id_auto=>"id", topics_pars=>'["id","ip","login","updated","ret"]', edit_pars=>'["id","ip","login","updated","ret"]', update_pars=>'["id","ret"]', is_login=>0, table_comment=>"security table for $table_name"};
  push @{$report->{sp}}, {statement=>$str_p, procedure_name=>$proc_name, projectid=>$ARGS->{projectid}, created=>$ARGS->{created}, is_tabilet=>1};

  my $ret = $dbh->do(
qq~DROP TABLE IF EXISTS $table_ip~) and $dbh->do(
qq~DROP PROCEDURE IF EXISTS $proc_name~) and $dbh->do(
$str_t) and $dbh->do(
qq~CREATE INDEX $table_ip~.qq~_ip ON $table_ip USING btree (ip)~) and $dbh->do(
qq~CREATE INDEX $table_ip~.qq~_updated ON $table_ip USING btree (updated)~) and $dbh->do(
$str_p);
  return $dbh->errstr;
}

1;
