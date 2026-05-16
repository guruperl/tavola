use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use JSON qw(decode_json);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use Tavola::Project::Spec::Validator;

my $repo = abs_path("$Bin/..");
my $scenario = 'manual_pk_fk';
my $spec = _read_json("$repo/specs/sqlmeta.project.json");

ok(eval { Tavola::Project::Spec::Validator->validate($spec); 1 }, 'sqlmeta-generated project spec validates');
is($spec->{introspection}->{source}, 'sqlmeta', 'introspection source records sqlmeta');
like(join("\n", @{$spec->{introspection}->{warnings}}), qr/manual primary key override/, 'manual PK warning is preserved');
like(join("\n", @{$spec->{introspection}->{warnings}}), qr/without a login procedure/, 'missing login procedure warning is preserved');
my @warning_codes = map { $_->{code} } @{$spec->{introspection}->{warningDetails}};
ok(grep { $_ eq 'table_manual_primary_key' } @warning_codes, 'manual PK warning code is preserved');
ok(grep { $_ eq 'auth_missing_login_procedure' } @warning_codes, 'missing login procedure warning code is preserved');
ok(!grep { !defined $_ || $_ eq '' || $_ eq 'unknown' } @warning_codes, 'reviewed spec warning codes are known');
is_deeply([ map { $_->{message} } @{$spec->{introspection}->{warningDetails}} ], $spec->{introspection}->{warnings}, 'reviewed spec warning detail messages mirror warning strings');

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

my $tmp = tempdir('tavola-sqlmeta-output-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $out = File::Spec->catdir($tmp, 'php');
system("$repo/script/generate-project", '--spec', "$repo/specs/sqlmeta.project.json", '--lang', 'php', '--out', $out, '--replace', '--deterministic') == 0
	or die "generation failed\n";

my $config = _read_json("$out/conf/config.json");
is($config->{Pubrole}, 'p', 'generated config keeps public role');
is($config->{Roles}->{u}->{Id_name}, 'public_id', 'generated config role id uses manual key');
is_deeply($config->{Roles}->{u}->{Attributes}, [ qw(public_id email u_firstname u_lastname) ], 'generated config attributes use auth fields');

my $api = _read_json("$out/api.json");
my %api_components = map { $_->{name} => $_ } @{$api->{components}};
ok($api_components{users}, 'generated API includes users component');
ok($api_components{posts}, 'generated API includes posts component');
my %posts_actions = map { $_->{name} => $_ } @{$api_components{posts}->{actions}};
is_deeply(_sorted($posts_actions{topics}->{allowed_groups}), [ qw(p u) ], 'generated API preserves posts public/protected topics');

SKIP: {
	my $fixture_path = "$repo/../sqlmeta/xmeta/testdata/contracts/$scenario.expanded_app_spec.json";
	skip 'sqlmeta sibling contract fixtures are not checked out', 3 unless -f $fixture_path;
	my $fixture = _read_json($fixture_path);
	is($fixture->{Spec}->{Name}, 'Manual PK/FK', 'sqlmeta manual PK/FK contract fixture is readable');
	is($fixture->{Spec}->{SchemaOverrides}->{PrimaryKeys}->[0]->{Columns}->[0], 'public_id', 'contract fixture records manual role key');
	is($fixture->{TableGrants}->[0]->{TraversalJoins}->[0]->{ChildColumn}, 'user_public_id', 'contract fixture records manual FK traversal');
}

SKIP: {
	my $project_path = "$repo/testdata/sqlmeta/contracts/invalid_overrides.project.json";
	my $warnings_path = "$repo/testdata/sqlmeta/contracts/invalid_overrides.warnings.txt";
	skip 'Tavola invalid override fixtures are not checked out', 10 unless -f $project_path && -f $warnings_path;
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
	my %invalid_warning_codes = map { $_->{code} => 1 } @{$invalid->{introspection}->{warningDetails}};
	ok($invalid_warning_codes{manual_pk_missing_column}
		&& $invalid_warning_codes{manual_fk_ambiguous_table}
		&& $invalid_warning_codes{manual_fk_composite}
		&& $invalid_warning_codes{manual_fk_missing_child_column}
		&& $invalid_warning_codes{auth_missing_login_procedure}, 'invalid override warning codes are preserved');
	is_deeply([ map { $_->{message} } @{$invalid->{introspection}->{warningDetails}} ], $invalid->{introspection}->{warnings}, 'warning detail messages mirror warning strings');
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

sub _sorted {
	my $list = shift || [];
	return [ sort @$list ];
}
