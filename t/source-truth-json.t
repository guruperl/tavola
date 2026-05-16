use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON qw(decode_json);
use Test::More;

use Tavola::Project::Exporter;
use Tavola::Project::JSONSchema;
use Tavola::Project::Spec;
use Tavola::Project::Spec::Validator;

my $repo = abs_path("$Bin/..");
my $spec_path = "$repo/specs/supportdesk.project.json";
my $spec = _read_json($spec_path);

ok(eval { Tavola::Project::Spec::Validator->validate($spec); 1 }, 'reviewed sqlmeta source-of-truth spec validates');
is($spec->{introspection}->{source}, 'sqlmeta', 'source records sqlmeta origin');
ok(!$spec->{introspection}->{warnings}, 'reviewed source-of-truth has no pending introspection warnings');
is($spec->{project}->{default}->{component}, 'tickets', 'reviewed default component is tickets');
is($spec->{roles}->[0]->{restriction}, q{status = 'active'}, 'reviewed role restriction is preserved');

my %components = map { $_->{name} => $_ } @{$spec->{components}};
is_deeply($components{tickets}->{public}, [ 'topics' ], 'tickets keeps public list access');
ok(!$components{teams}->{public}, 'teams is protected-only after review');
ok(!$components{ticket_notes}->{public}, 'ticket notes are protected-only after review');
is_deeply($components{users}->{roles}->{u}, [ qw(edit update topics) ], 'users role actions are narrowed by review');
ok(!$components{audit_events}->{roles}, 'unscoped audit table remains outside protected role grants');

my ($one, $other) = Tavola::Project::Spec->new(
	config_path => "$repo/conf/config.json",
	spec_path => $spec_path,
)->export_data();

my $config = decode_json($one->{config_json});
is($config->{Project}, 'SupportDesk', 'metadata export uses reviewed project name');
is($config->{Roles}->{u}->{Issuers}->{db}->{Sql}, 'proc_u_login', 'metadata export wires reviewed login procedure');
is_deeply($config->{Roles}->{u}->{Attributes}, [ qw(id email u_firstname u_lastname) ], 'metadata export wires reviewed auth attributes');

my %role_acl = map { $_->{name_component} => $_ } @{$one->{role_role_acl}};
ok($role_acl{tickets}, 'role ACL includes tickets');
ok($role_acl{teams}, 'role ACL includes teams');
ok($role_acl{ticket_notes}, 'role ACL includes ticket notes');
ok($role_acl{users}, 'role ACL includes reviewed users permissions');
ok(!$role_acl{audit_events}, 'role ACL excludes audit events');

my $tmp = tempdir('tavola-source-truth-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $schema = _read_json("$repo/docs/api.schema.json");
for my $lang (qw(php perl go)) {
	my $out = File::Spec->catdir($tmp, $lang);
	Tavola::Project::Exporter->new(
		config_path => "$repo/conf/config.json",
		lang => $lang,
		data => [ $one, $other ],
		web_ui => 0,
		asset_root => $repo,
	)->write_dir($out, 1);

	my $api = _read_json("$out/api.json");
	my @errors = Tavola::Project::JSONSchema->new(schema => $schema)->validate($api);
	is_deeply(\@errors, [], "$lang generated api.json matches schema");
	is($api->{project}->{name}, 'SupportDesk', "$lang generated API uses reviewed source");
	is($api->{project}->{default}->{component}, 'tickets', "$lang generated API keeps reviewed default");
	my %roles = map { $_->{name} => $_ } @{$api->{roles}};
	is($roles{u}->{login}->{sql}, 'proc_u_login', "$lang generated API keeps SQLite login procedure binding");
	_assert_component_actions($api, $lang);
	my $init_sql = _read_text("$out/conf/init.sql");
	like($init_sql, qr/SQLite does not support stored procedure DDL/, "$lang generated SQLite init documents omitted procedure DDL");
	unlike($init_sql, qr/DROP PROCEDURE|DELIMITER/, "$lang generated SQLite init avoids non-SQLite procedure syntax");
	ok(-s "$out/openapi.json", "$lang generated openapi.json from reviewed source");
}

done_testing();

sub _assert_component_actions {
	my ($api, $lang) = @_;
	my %components = map { $_->{name} => $_ } @{$api->{components}};
	my %ticket_actions = map { $_->{name} => $_ } @{$components{tickets}->{actions}};
	is_deeply(_sorted($ticket_actions{topics}->{allowed_groups}), [ qw(p u) ], "$lang tickets topics are public and protected");
	is_deeply($ticket_actions{insert}->{allowed_groups}, [ 'u' ], "$lang tickets insert is protected");

	my %team_actions = map { $_->{name} => $_ } @{$components{teams}->{actions}};
	is_deeply($team_actions{topics}->{allowed_groups}, [ 'u' ], "$lang teams topics are protected-only");

	my %user_actions = map { $_->{name} => $_ } @{$components{users}->{actions}};
	is_deeply($user_actions{topics}->{allowed_groups}, [ 'u' ], "$lang users topics are protected-only");
	ok(!$user_actions{insert}, "$lang reviewed users component has no insert action");
	ok(!$user_actions{delete}, "$lang reviewed users component has no delete action");
}

sub _read_json {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $json = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return decode_json($json);
}

sub _read_text {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $text = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return $text;
}

sub _sorted {
	my $list = shift || [];
	return [ sort @$list ];
}
