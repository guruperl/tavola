package Tabilet::SchemaDatabase;

use strict;
use Data::Dumper;
use Tabilet::Schema;

use vars qw(@ISA);
@ISA = ('Tabilet::Schema');

sub set_dbh {
	my $self = shift;
	my $form = shift;
	my $custom = shift;
	$self->{DBNAME} = shift || 'postgres';

	my $ARGS = $self->{ARGS};
	if ($ARGS->{dbtype}) {
		$self->{DBTYPE} = $ARGS->{dbtype};
	} else {
		my $err = $form->call_once({model=>"ds", action=>"topics"}, {projectid=>$ARGS->{projectid}});
		return $err if $err;
		$self->{DBTYPE} = $form->{OTHER}->{ds_topics}->[0]->{dbtype};
	}

	my $c = $custom->{$self->{DBTYPE}};
	for (qw(host port dbuser dbpass)) {
		$self->{uc $_} = $c->{$_};
	}

	return $self->_set_dbh();
}

sub create_database {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $host = $ARGS->{host};
	my $dbname = $ARGS->{dbname};
	my $user = $ARGS->{dbuser};
	my $pass = $ARGS->{dbpass};
	return 3203 unless (Tabilet::Schema::is_identifier($dbname) && Tabilet::Schema::is_identifier($user));

	my $q_dbname = $self->quote_identifier($dbname);
	my $q_user   = $self->quote_identifier($user);
	my $q_host   = $self->{DBH}->quote($host);
	my $q_pass   = $self->{DBH}->quote($pass);

	if ($ARGS->{dbtype} eq 'PostgreSQL') {
		return $self->do_sql(
qq~CREATE DATABASE $q_dbname~) || $self->do_sql(
qq~CREATE USER $q_user WITH ENCRYPTED PASSWORD $q_pass~) || $self->do_sql(
qq~GRANT ALL PRIVILEGES ON DATABASE $q_dbname TO $q_user~);
	}

	return $self->do_sql(
qq~CREATE DATABASE $q_dbname~) || $self->do_sql(
qq~GRANT ALL PRIVILEGES ON $q_dbname.* TO $q_user\@$q_host IDENTIFIED BY $q_pass~) || $self->do_sql(
qq~GRANT ALTER ROUTINE, CREATE ROUTINE, EXECUTE ON $q_dbname.* TO $q_user\@$q_host~) || $self->do_sql(
qq~FLUSH PRIVILEGES~) || $self->do_sql(
qq~USE $q_dbname~);
}

sub create_extension {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	return $self->do_sql(qq~CREATE EXTENSION IF NOT EXISTS pgcrypto~);
}

sub drop_database {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	return 3203 unless (Tabilet::Schema::is_identifier($ARGS->{dbname}) && Tabilet::Schema::is_identifier($ARGS->{dbuser}));

	my $q_dbname = $self->quote_identifier($ARGS->{dbname});
	my $q_user   = $self->quote_identifier($ARGS->{dbuser});
	my $q_host   = $self->{DBH}->quote($ARGS->{host});

	if ($ARGS->{dbtype} eq 'PostgreSQL') {
		return $self->do_sql(
qq~DROP DATABASE IF EXISTS $q_dbname~) || $self->do_sql(
qq~DROP USER IF EXISTS $q_user~);
	}

	return $self->do_sql(
qq~DROP DATABASE $q_dbname~) || $self->do_sql(
qq~DROP USER $q_user\@$q_host~);
}

sub drop_extension {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	return $self->do_sql(qq~DROP EXTENSION IF EXISTS pgcrypto~);
}

1;
