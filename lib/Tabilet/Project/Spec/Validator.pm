package Tabilet::Project::Spec::Validator;

use strict;
use warnings;

sub validate {
	my ($class, $spec) = @_;

	die "Spec version must be 1\n" unless ($spec->{version} || 0) == 1;
	for my $block (qw(owner project datasource schema roles components overlays)) {
		die "Spec is missing top-level block '$block'\n" unless exists $spec->{$block};
	}

	_required($spec->{owner}, qw(login email typeid));
	_required($spec->{project}, qw(name script publicRole default));
	_required($spec->{project}->{default}, qw(component action));
	_validate_datasource($spec->{datasource});

	die "schema.tables must be an array\n" unless ref($spec->{schema}->{tables}) eq 'ARRAY';
	die "schema.procedures must be an array\n" unless ref($spec->{schema}->{procedures}) eq 'ARRAY';
	die "roles must be an array\n" unless ref($spec->{roles}) eq 'ARRAY';
	die "components must be an array\n" unless ref($spec->{components}) eq 'ARRAY';
	die "overlays must be an object\n" unless ref($spec->{overlays}) eq 'HASH';

	my %tables;
	for my $table (@{$spec->{schema}->{tables}}) {
		_required($table, qw(name primaryKey));
		die "Table $table->{name} needs statement or statementFile\n" unless $table->{statement} || $table->{statementFile};
		$tables{$table->{name}} = 1;
		_assert_array($table, $_) for grep { exists $table->{$_} } qw(insert edit update topics fks uniques nons);
	}

	for my $procedure (@{$spec->{schema}->{procedures}}) {
		_required($procedure, qw(name));
		die "Procedure $procedure->{name} needs statement or statementFile\n" unless $procedure->{statement} || $procedure->{statementFile};
		die "Procedure $procedure->{name} references unknown table '$procedure->{table}'\n"
			if $procedure->{table} && !$tables{$procedure->{table}};
	}

	my %roles;
	for my $role (@{$spec->{roles}}) {
		_required($role, qw(name description authen fields restriction));
		_required($role->{fields}, qw(id login password));
		die "Role $role->{name} references unknown table '$role->{table}'\n"
			if $role->{table} && !$tables{$role->{table}};
		$roles{$role->{name}} = 1;
	}

	for my $component (@{$spec->{components}}) {
		_required($component, qw(name description table));
		die "Component $component->{name} references unknown table '$component->{table}'\n"
			unless $tables{$component->{table}};
		_assert_array($component, $_) for grep { exists $component->{$_} } qw(public);
		if ($component->{roles}) {
			die "Component $component->{name} roles must be an object\n" unless ref($component->{roles}) eq 'HASH';
			for my $role (keys %{$component->{roles}}) {
				die "Component $component->{name} references unknown role '$role'\n" unless $roles{$role};
			}
		}
	}

	return;
}

sub _required {
	my ($hash, @keys) = @_;
	die "Expected object while validating required fields\n" unless ref($hash) eq 'HASH';
	for my $key (@keys) {
		die "Missing required field '$key'\n" unless exists $hash->{$key} && defined $hash->{$key};
	}
}

sub _validate_datasource {
	my $ds = shift;
	_required($ds, qw(type nickname));
	my $family = _db_family($ds->{type});
	if ($family eq 'sqlite') {
		die "SQLite datasource needs 'database' or 'path'\n" unless $ds->{database} || $ds->{path};
		return;
	}
	_required($ds, qw(database host port user password));
	return;
}

sub _db_family {
	my $type = shift;
	my $normalized = lc($type || '');
	$normalized =~ s/[^a-z0-9]//g;
	return 'mysql' if $normalized eq 'mysql' || $normalized eq 'mariadb';
	return 'postgresql' if $normalized eq 'postgresql' || $normalized eq 'postgres' || $normalized eq 'pgsql';
	return 'sqlite' if $normalized eq 'sqlite' || $normalized eq 'sqlite3';
	die "Unsupported datasource type '$type'. Use MySQL, PostgreSQL, or SQLite.\n";
}

sub _assert_array {
	my ($hash, $key) = @_;
	die "$key must be an array\n" unless ref($hash->{$key}) eq 'ARRAY';
}

1;
