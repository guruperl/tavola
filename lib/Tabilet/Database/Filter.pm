package Tabilet::Database::Filter;

use strict;
use Text::CSV;
use Genelet::Utils;
use Tabilet::Schema;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

__PACKAGE__->setup_accessors(
    'is_upload' => 1,
);

sub fks {
	my $self = shift;
	return $self->SUPER::fks(@_) if @_;

	my $ARGS = $self->{ARGS};
	return {member=>["memberid",undef]} if ($ARGS->{g_action} eq 'topics');

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

	if ($action eq 'csv') {
		my $ref = {};
		my %allowed_type = map { $_ => 1 } qw(CHAR VARCHAR TEXT INT INTEGER BIGINT FLOAT DOUBLE DECIMAL DATE DATETIME TIMESTAMP BOOLEAN);
		for my $k (%$ARGS) {
			next unless ($k =~ /^type(\d+)$/);
			return 3203 unless $allowed_type{$ARGS->{$k}};
			$ref->{$1} = 1 if ($ARGS->{$k} eq 'VARCHAR');
		}
		my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
		my $fh;
		open $fh, "<:encoding(utf8)", $ARGS->{dir_dbfile} ."/". $ARGS->{dbfile} or return $!;
		my $i=0;
		while (my $row = $csv->getline ($fh)) {
			# get the column names
			if ($i==0) {
				my %seen;
				for my $c (@$row) {
					$c =~ s/\s+/_/g;
					$c =~ s/[^A-Za-z0-9_]/_/g;
					$c = "col_$c" unless ($c =~ /^[A-Za-z_]/);
					$c ||= "col";
					my $base = $c;
					my $num = 2;
					$c = $base . "_" . $num++ while $seen{$c}++;
					push @{$ARGS->{names}}, $c;
				}
				$i++;
				next;
			}
			# get row lengths
			for my $num (keys %$ref) {
				my $c = $row->[$num];
				$ref->{$num} = length($c) if (length($c)>$ref->{$num});
			}
		}
		close $fh;
		my $dbfile = $ARGS->{dbfile};
		$dbfile =~ s/\./_/g;
		$dbfile =~ s/[^A-Za-z0-9_]/_/g;
		$dbfile = "table_$dbfile" unless ($dbfile =~ /^[A-Za-z_]/);
		return 3203 unless Tabilet::Schema::is_identifier($dbfile);
		my $n = @{$ARGS->{names}};
		my $str = qq~DROP TABLE IF EXISTS $dbfile;
CREATE TABLE $dbfile (
  tabilet_id ~;
		$str .= ($ARGS->{dbtype} eq 'MySQL') ? "int auto_increment" : "serial";
		$str .= qq~ NOT NULL PRIMARY KEY,
~;
		for (my $i=0; $i<$n; $i++) {
			$str .= "  " . $ARGS->{names}->[$i] . " ";
			if ($ARGS->{dbtype} eq 'MySQL')  {
				if ($ref->{$i} && $ref->{$i}>255) {
					$str .= "TEXT";
				} elsif ($ref->{$i}) {
					$str .= "VARCHAR(255)";
				} else {
					$str .= $ARGS->{"type$i"};
				}
			} else {
				$str .=($ref->{$i})?"VARCHAR(".$ref->{$i}.")":$ARGS->{"type$i"};
			}
			$str .= ",\n";
		}
		substr($str,-2,2) = "\n);";
		$ARGS->{statement} = $str;
		$ARGS->{ref} = $ref;
		$ARGS->{ins} = qq~INSERT INTO $dbfile (~ . join(',', @{$ARGS->{names}}) . ") VALUES (" . join(",", ("?")x$n) . ")";
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

	$err = $form->get_dstype() and return $err;
	my $schema = Tabilet::Schema->new(args=>$ARGS, logger=>$self->{LOGGER});
	$err = $schema->set_dbh($form) and return $err;

	# do nothing for topics
	if ($action eq 'csv') {
		$err = $schema->insert() and return $err;
		my $ins = $schema->{DBH}->prepare($ARGS->{ins});
		my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
		my $fh;
		open $fh, "<:encoding(utf8)", $ARGS->{dir_dbfile} ."/". $ARGS->{dbfile} or return $!;
		my $k=0;
		while (my $row = $csv->getline ($fh)) {
			if ($k==0) {
				$k++;
				next;
			}
			for (my $i=0; $i<@{$ARGS->{names}}; $i++) {
				next if $ARGS->{ref}->{$i};
				$row->[$i] =~ s/,//;
			}
			$ins->execute(@$row) or return $schema->{DBH}->errstr();
		}
		close($fh);
		$ins->finish;
		$err = $schema->sync($form) and return $err;
	} elsif ($action eq 'insert') {
		$ARGS->{fast_mysql} = 1 if ($ARGS->{dbtype} eq 'MySQL');
		$err = $schema->insert() || $schema->sync($form);
		return $err if $err;
	} elsif ($action eq 'sync') {
		$ARGS->{fast_mysql} = 1 if ($ARGS->{dbtype} eq 'MySQL');
		$err = $schema->sync($form) and return $err;
	} elsif ($action eq 'edit') {
		$err = $schema->edit() and return $err;
		$form->{LISTS} = $schema->{LISTS};
	} elsif ($action eq 'delete') {
		$err = $schema->delete() and return $err;
	}

	$schema->{DBH}->disconnect;

	if ($action eq 'topics') {
		$onceextras->[0] = {projectid=>$ARGS->{projectid}};
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
	my $lists  = $form->{LISTS};
	my $other  = $form->{OTHER};

	return;
}

1;
