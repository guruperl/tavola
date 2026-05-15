use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use JSON qw(decode_json);
use Test::More;

use Tavola::Project::Spec;
use Tavola::Project::Spec::Validator;

my $repo = abs_path("$Bin/..");
my $scenario = 'manual_pk_fk';
my $spec = _read_json("$repo/specs/sqlmeta.project.json");

ok(eval { Tavola::Project::Spec::Validator->validate($spec); 1 }, 'sqlmeta-generated project spec validates');
is($spec->{introspection}->{source}, 'sqlmeta', 'introspection source records sqlmeta');
like(join("\n", @{$spec->{introspection}->{warnings}}), qr/manual primary key override/, 'manual PK warning is preserved');
like(join("\n", @{$spec->{introspection}->{warnings}}), qr/without a login procedure/, 'missing login procedure warning is preserved');

is($spec->{project}->{publicRole}, 'p', 'public role remains p');

my %tables = map { $_->{name} => $_ } @{$spec->{schema}->{tables}};
is($tables{users}->{primaryKey}, 'public_id', 'manual PK becomes Tavola role table key');
is($tables{users}->{autoKey}, 'id', 'physical auto key remains table metadata');

my %roles = map { $_->{name} => $_ } @{$spec->{roles}};
is($roles{u}->{table}, 'users', 'auth role points at user table');
is($roles{u}->{fields}->{id}, 'public_id', 'auth id comes from AuthBinding user id');
is($roles{u}->{fields}->{login}, 'email', 'auth login comes from AuthBinding login');
is($roles{u}->{fields}->{password}, 'passwd', 'auth password comes from AuthBinding password');
is($roles{u}->{fields}->{firstname}, 'firstname', 'auth firstname comes from AuthBinding firstname');
is($roles{u}->{fields}->{lastname}, 'lastname', 'auth lastname comes from AuthBinding lastname');

my %components = map { $_->{name} => $_ } @{$spec->{components}};
ok($components{users}->{roles}->{u}, 'auth table receives protected role CRUD');
ok($components{posts}->{roles}->{u}, 'manual FK descendant receives protected role CRUD');
ok(!$components{audit_log}->{roles}, 'unrelated table has no protected role CRUD');
is_deeply($components{posts}->{roles}->{u}, [ qw(startnew insert edit update delete topics) ], 'protected CRUD actions are preserved');

my ($one, $other) = Tavola::Project::Spec->new(
	config_path => "$repo/conf/config.json",
	spec_path => "$repo/specs/sqlmeta.project.json",
)->export_data();

my %table_rows = map { $_->{table_name} => $_ } @{$one->{table_topics}};
is($table_rows{users}->{current_key}, 'public_id', 'metadata builder uses manual role key');
is($table_rows{posts}->{current_key}, 'id', 'metadata builder keeps child table key');

my %role_rows = map { $_->{name_role} => $_ } @{$one->{role_topics}};
is($role_rows{u}->{field_id}, 'public_id', 'role config id uses manual key');
is($role_rows{u}->{field_login}, 'email', 'role config login field is preserved');
is($role_rows{u}->{field_passwd}, 'passwd', 'role config password field is preserved');

my %role_acl = map { $_->{name_component} => $_ } @{$one->{role_role_acl}};
ok($role_acl{users}, 'role ACL includes users component');
ok($role_acl{posts}, 'role ACL includes posts component');
ok(!$role_acl{audit_log}, 'role ACL excludes unrelated audit_log component');

my $config = decode_json($one->{config_json});
is($config->{Pubrole}, 'p', 'generated config keeps public role');
is($config->{Roles}->{u}->{Id_name}, 'public_id', 'generated config role id uses manual key');
is_deeply($config->{Roles}->{u}->{Attributes}, [ qw(public_id email u_firstname u_lastname) ], 'generated config attributes use auth fields');

ok(ref($other->{r_list}) eq 'ARRAY', 'landing list is generated from consumed spec');

SKIP: {
	my $fixture_path = "$repo/../sqlmeta/xmeta/testdata/contracts/$scenario.expanded_app_spec.json";
	skip 'sqlmeta sibling contract fixtures are not checked out', 3 unless -f $fixture_path;
	my $fixture = _read_json($fixture_path);
	is($fixture->{Spec}->{Name}, 'Manual PK/FK', 'sqlmeta manual PK/FK contract fixture is readable');
	is($fixture->{Spec}->{SchemaOverrides}->{PrimaryKeys}->[0]->{Columns}->[0], 'public_id', 'contract fixture records manual role key');
	is($fixture->{TableGrants}->[0]->{TraversalJoins}->[0]->{ChildColumn}, 'user_public_id', 'contract fixture records manual FK traversal');
}

SKIP: {
	my $project_path = "$repo/../sqlmeta/tavola/testdata/contracts/invalid_overrides.project.json";
	my $warnings_path = "$repo/../sqlmeta/tavola/testdata/contracts/invalid_overrides.warnings.txt";
	skip 'sqlmeta sibling invalid override fixtures are not checked out', 8 unless -f $project_path && -f $warnings_path;
	my $invalid = _read_json($project_path);
	ok(eval { Tavola::Project::Spec::Validator->validate($invalid); 1 }, 'invalid override project fixture validates');
	open my $fh, '<', $warnings_path or die "Cannot open $warnings_path: $!";
	local $/;
	my $warnings = <$fh>;
	close $fh or die "Cannot close $warnings_path: $!";
	$warnings =~ s/\s+\z//;
	is($warnings, join("\n", @{$invalid->{introspection}->{warnings}}), 'invalid override warning snapshot matches project JSON');
	like($warnings, qr/missing_public_id/, 'invalid manual PK warning is preserved');
	like($warnings, qr/ambiguous table name matched archive\.teams, public\.teams/, 'ambiguous table warning is preserved');
	like($warnings, qr/composite columns; skipped role scope edge/, 'composite manual FK warning is preserved');
	like($warnings, qr/missing_user_id/, 'invalid manual FK warning is preserved');
	my %invalid_components = map { $_->{table} => $_ } @{$invalid->{components}};
	ok($invalid_components{users}->{roles}->{u} && $invalid_components{posts}->{roles}->{u}, 'valid auth-scope tables receive protected grants');
	ok(!$invalid_components{audit_log}->{roles} && !$invalid_components{memberships}->{roles}, 'unrelated and skipped-FK tables receive no protected grants');
}

done_testing();

sub _read_json {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $json = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return decode_json($json);
}
