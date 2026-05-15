use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON qw(decode_json);
use Test::More;

use Tabilet::Project::Exporter;
use Tabilet::Project::JSONSchema;
use Tabilet::Project::Spec;

my $repo = abs_path("$Bin/..");
my $tmp = tempdir('tabilet-generated-test-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $schema = _read_json("$repo/docs/api.schema.json");

for my $lang (qw(php perl)) {
	my $out = _generate($lang);
	my $api = _read_json("$out/api.json");
	my @errors = Tabilet::Project::JSONSchema->new(schema => $schema)->validate($api);
	is_deeply(\@errors, [], "$lang api.json matches schema");

	ok(-s "$out/docs/api.md", "$lang generated docs/api.md");
	ok(-s "$out/docs/api.schema.json", "$lang generated docs/api.schema.json");
	ok(-s "$out/conf/config.json", "$lang generated conf/config.json");

	_assert_api_manifest($api, $lang);
	_assert_config(_read_json("$out/conf/config.json"), $lang);
	_assert_component_json(_component_json_path($out, $lang), $lang);
}

done_testing();

sub _generate {
	my $lang = shift;
	my $out = File::Spec->catdir($tmp, $lang);
	my $loader = Tabilet::Project::Spec->new(
		config_path => "$repo/conf/config.json",
		spec_path => "$repo/specs/project.template.json",
	);
	my ($one, $other) = $loader->export_data();
	Tabilet::Project::Exporter->new(
		config_path => "$repo/conf/config.json",
		lang => $lang,
		data => [ $one, $other ],
		web_ui => 0,
		asset_root => $repo,
	)->write_dir($out, 1);
	return $out;
}

sub _assert_api_manifest {
	my ($api, $lang) = @_;

	is($api->{format}, 'tabilet-api-manifest', "$lang api format");
	is($api->{version}, 1, "$lang api version");
	is($api->{project}->{name}, 'ExampleApp', "$lang project name");
	is($api->{project}->{script}, '/example/app.php', "$lang script");
	is($api->{project}->{public_role}, 'p', "$lang public role");
	is_deeply($api->{project}->{default}, { component => 'item', action => 'topics' }, "$lang default route");

	my %roles = map { $_->{name} => $_ } @{$api->{roles}};
	ok($roles{p}, "$lang public role exists");
	ok($roles{u}, "$lang user role exists");
	ok($roles{p}->{public}, "$lang p is public");
	ok(!$roles{p}->{auth_required}, "$lang p does not require auth");
	ok(!$roles{u}->{public}, "$lang u is protected role");
	ok($roles{u}->{auth_required}, "$lang u requires auth");
	is($roles{u}->{login}->{endpoint}, '/example/app.php/u/json/login', "$lang u login endpoint");
	is_deeply($roles{u}->{login}->{credentials}, [ qw(email passwd) ], "$lang u login credentials");
	is($roles{u}->{login}->{sql}, 'proc_example_u', "$lang u login procedure");

	is(scalar @{$api->{components}}, 1, "$lang component count");
	my $item = $api->{components}->[0];
	is($item->{name}, 'item', "$lang component name");
	is($item->{table}, 'item', "$lang component table");
	is($item->{primary_key}, 'item_id', "$lang component primary key");

	my %actions = map { $_->{name} => $_ } @{$item->{actions}};
	is_deeply(_sorted($actions{topics}->{allowed_groups}), [ qw(p u) ], "$lang topics groups");
	is_deeply($actions{topics}->{request_params}, [ qw(item_id title owner_id created) ], "$lang topics params");
	is($actions{topics}->{examples}->{json}, '/example/app.php/p/json/item?action=topics', "$lang topics JSON example");
	is($actions{topics}->{examples}->{html}, '/example/app.php/p/html/item?action=topics', "$lang topics HTML example");
	ok($actions{topics}->{public}, "$lang topics is public");

	is_deeply($actions{startnew}->{allowed_groups}, [ 'u' ], "$lang startnew groups");
	is_deeply($actions{startnew}->{options}, [ qw(no_db no_method) ], "$lang startnew options");
	is_deeply($actions{startnew}->{request_params}, [], "$lang startnew params");

	is_deeply($actions{insert}->{allowed_groups}, [ 'u' ], "$lang insert groups");
	is_deeply($actions{insert}->{request_params}, [ qw(title owner_id created) ], "$lang insert params");
	is_deeply($actions{edit}->{request_params}, [ qw(item_id title owner_id created) ], "$lang edit params");
	is_deeply($actions{update}->{request_params}, [ qw(item_id title owner_id) ], "$lang update params");
}

sub _assert_config {
	my ($config, $lang) = @_;

	is($config->{Project}, 'ExampleApp', "$lang config project");
	is($config->{Pubrole}, 'p', "$lang config public role");
	ok($config->{Roles}->{u}, "$lang config u role");

	my $role = $config->{Roles}->{u};
	is($role->{Id_name}, 'user_id', "$lang config role id");
	is_deeply($role->{Attributes}, [ qw(user_id email u_firstname u_lastname) ], "$lang config role attributes");
	is($role->{Surface}, 'tu', "$lang config role surface");

	my $issuer = $role->{Issuers}->{db};
	ok($issuer, "$lang config db issuer");
	is($issuer->{Sql}, 'proc_example_u', "$lang config db issuer sql");
	is_deeply($issuer->{Credential}, [ qw(email passwd direct tu) ], "$lang config db credentials");
	is_deeply($issuer->{In_pars}, [ qw(email passwd) ], "$lang config db input params");
	is_deeply($issuer->{Out_pars}, [ qw(user_id email u_firstname u_lastname) ], "$lang config db output params");
}

sub _assert_component_json {
	my ($path, $lang) = @_;
	my $component = _read_json($path);

	is($component->{current_table}, 'item', "$lang component json table");
	is($component->{current_key}, 'item_id', "$lang component json primary key");
	is($component->{current_id_auto}, 'item_id', "$lang component json auto key");
	is_deeply(_sorted($component->{actions}->{topics}->{groups}), [ qw(p u) ], "$lang component json topics groups");
	is_deeply($component->{actions}->{startnew}->{groups}, [ 'u' ], "$lang component json startnew groups");
	is_deeply($component->{actions}->{startnew}->{options}, [ qw(no_db no_method) ], "$lang component json startnew options");
	is_deeply($component->{insert_pars}, [ qw(title owner_id created) ], "$lang component json insert params");
	is_deeply($component->{edit_pars}, [ qw(item_id title owner_id created) ], "$lang component json edit params");
	is_deeply($component->{update_pars}, [ qw(item_id title owner_id) ], "$lang component json update params");
	is_deeply($component->{topics_pars}, [ qw(item_id title owner_id created) ], "$lang component json topics params");
}

sub _component_json_path {
	my ($out, $lang) = @_;
	return "$out/src/item/component.json" if $lang eq 'php';
	return "$out/lib/ExampleApp/Item/component.json";
}

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
