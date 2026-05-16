use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON qw(decode_json encode_json);
use Test::More;

use Tavola::Project::Exporter;
use Tavola::Project::JSONSchema;
use Tavola::Project::Spec;
use Tavola::Project::Spec::Importer;
use Tavola::Generator::Go;

my $repo = abs_path("$Bin/..");
my $tmp = tempdir('tavola-generated-test-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $schema = _read_json("$repo/docs/api.schema.json");

for my $lang (qw(php perl go)) {
	my $out = _generate($lang);
	my $api = _read_json("$out/api.json");
	my $openapi = _read_json("$out/openapi.json");
	my @errors = Tavola::Project::JSONSchema->new(schema => $schema)->validate($api);
	is_deeply(\@errors, [], "$lang api.json matches schema");

	ok(-s "$out/openapi.json", "$lang generated openapi.json");
	ok(-s "$out/docs/api.md", "$lang generated docs/api.md");
	ok(-s "$out/docs/api.schema.json", "$lang generated docs/api.schema.json");
	ok(-s "$out/conf/config.json", "$lang generated conf/config.json");

	_assert_api_manifest($api, $lang);
	_assert_openapi($openapi, $lang);
	_assert_api_docs(_read_text("$out/docs/api.md"), $lang);
	_assert_config(_read_json("$out/conf/config.json"), $lang);
	_assert_component_json(_component_json_path($out, $lang), $lang);
}

_assert_go_overlay_and_templates();
_assert_go_auth_key_compatibility();
_assert_go_overlay_import_guard();
_assert_go_readme_endpoint_selection();

done_testing();

sub _generate {
	my $lang = shift;
	my $out = File::Spec->catdir($tmp, $lang);
	my $loader = Tavola::Project::Spec->new(
		config_path => "$repo/conf/config.json",
		spec_path => "$repo/specs/project.template.json",
	);
	my ($one, $other) = $loader->export_data();
	Tavola::Project::Exporter->new(
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

	is($api->{format}, 'tavola-api-manifest', "$lang api format");
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
	if ($lang eq 'go') {
		ok(!$config->{Db}, "$lang config omits PHP/Perl Db");
		is_deeply($config->{ConnectArray}, [ 'mysql', '${APP_DB_USER}', '${APP_DB_PASSWORD}', '127.0.0.1', '3306', 'example' ], "$lang config uses structured Go ConnectArray");
		is($config->{ServerURL}, 'http://example.localhost', "$lang config uses Go ServerURL key");
		is($config->{DocumentRoot}, '/tmp/tavola/generated/example/www', "$lang config uses Go DocumentRoot key");
		is($config->{UploadDir}, '/tmp/tavola/generated/example/www/upload', "$lang config uses Go UploadDir key");
		is($config->{Chartags}->{json}->{ContentType}, "application/json; charset='UTF-8'", "$lang config uses Go chartag content type key");
	}

	my $role = $config->{Roles}->{u};
	is($role->{Id_name}, 'user_id', "$lang config role id");
	is_deeply($role->{Attributes}, [ qw(user_id email u_firstname u_lastname) ], "$lang config role attributes");
	is($role->{Surface}, 'tu', "$lang config role surface");

	my $issuer = $role->{Issuers}->{db};
	ok($issuer, "$lang config db issuer");
	is($issuer->{Sql}, 'proc_example_u', "$lang config db issuer sql");
	is_deeply($issuer->{Credential}, [ qw(email passwd direct tu) ], "$lang config db credentials");
	my $in_key = $lang eq 'go' ? 'InPars' : 'In_pars';
	my $out_key = $lang eq 'go' ? 'OutPars' : 'Out_pars';
	is_deeply($issuer->{$in_key}, [ qw(email passwd) ], "$lang config db input params");
	is_deeply($issuer->{$out_key}, [ qw(user_id email u_firstname u_lastname) ], "$lang config db output params");
}

sub _assert_openapi {
	my ($openapi, $lang) = @_;

	is($openapi->{openapi}, '3.0.3', "$lang OpenAPI version");
	is($openapi->{info}->{title}, 'ExampleApp API', "$lang OpenAPI title");
	is($openapi->{'x-tavola-source'}, 'api.json', "$lang OpenAPI source extension");
	is($openapi->{'x-tavola-endpoint-pattern'}, '<script>/<role>/<tag>/<component>?action=<action>', "$lang OpenAPI endpoint pattern extension");

	my $login = $openapi->{paths}->{'/example/app.php/{role}/json/login'}->{post};
	ok($login, "$lang OpenAPI login path");
	is_deeply($login->{parameters}->[0]->{schema}->{enum}, [ 'u' ], "$lang OpenAPI login roles");
	is_deeply($login->{'x-tavola-logins'}->[0]->{credentials}, [ qw(email passwd) ], "$lang OpenAPI login credentials");

	my $component = $openapi->{paths}->{'/example/app.php/{role}/json/item'}->{get};
	ok($component, "$lang OpenAPI component path");
	is_deeply($component->{parameters}->[0]->{schema}->{enum}, [ qw(p u) ], "$lang OpenAPI component roles");
	is_deeply($component->{parameters}->[1]->{schema}->{enum}, [ qw(topics startnew insert edit update) ], "$lang OpenAPI action enum");
	is($component->{'x-tavola-component'}->{primary_key}, 'item_id', "$lang OpenAPI component primary key");
	my %actions = map { $_->{name} => $_ } @{$component->{'x-tavola-actions'}};
	is_deeply(_sorted($actions{topics}->{allowed_groups}), [ qw(p u) ], "$lang OpenAPI topics groups");
	is_deeply($actions{insert}->{request_params}, [ qw(title owner_id created) ], "$lang OpenAPI insert params");
}

sub _assert_api_docs {
	my ($docs, $lang) = @_;

	like($docs, qr/### Role `u` Login/, "$lang docs include role login heading");
	like($docs, qr/- Endpoint: `\/example\/app\.php\/u\/json\/login`/, "$lang docs include login endpoint");
	like($docs, qr/- Request parameters: `email`, `passwd`/, "$lang docs include login request params");
	like($docs, qr/- Login procedure: `proc_example_u`/, "$lang docs include login procedure");
	like($docs, qr/\| `login` \| `email` \|/, "$lang docs include login field mapping");
	like($docs, qr/\| `password` \| `passwd` \|/, "$lang docs include password field mapping");
	like($docs, qr/\/example\/app\.php\/u\/json\/login\?email=<email>&passwd=<passwd>/, "$lang docs include login request example");
	like($docs, qr/After login, call protected actions with the returned session\/cookie:/, "$lang docs include protected action flow");
	like($docs, qr/\| `item` \| `topics` \| `item_id`, `title`, `owner_id`, `created` \| `\/example\/app\.php\/u\/json\/item\?action=topics` \|/, "$lang docs include protected topics example");
	like($docs, qr/\| `item` \| `insert` \| `title`, `owner_id`, `created` \| `\/example\/app\.php\/u\/json\/item\?action=insert` \|/, "$lang docs include protected insert example");
	like($docs, qr/\| `item` \| `update` \| `item_id`, `title`, `owner_id` \| `\/example\/app\.php\/u\/json\/item\?action=update` \|/, "$lang docs include protected update example");
	like($docs, qr/primary machine-readable contract.*`api\.json`.*derived OpenAPI document.*`openapi\.json`/, "$lang docs mention api and OpenAPI files");
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

sub _assert_go_overlay_and_templates {
	my $case_dir = File::Spec->catdir($tmp, 'go-overlay-case');
	make_path(File::Spec->catdir($case_dir, 'overlays', 'internal', 'item'));

	my $spec = _read_json("$repo/specs/project.template.json");
	$spec->{overlays}->{components}->{item} = {
		goModelFile => 'overlays/internal/item/model.go',
		goFilterFile => 'overlays/internal/item/filter.go',
	};
	_write_text(File::Spec->catfile($case_dir, 'project.json'), encode_json($spec));
	_write_text(File::Spec->catfile($case_dir, 'overlays', 'internal', 'item', 'model.go'), _go_model_overlay());
	_write_text(File::Spec->catfile($case_dir, 'overlays', 'internal', 'item', 'filter.go'), _go_filter_overlay());

	my $loader = Tavola::Project::Spec->new(
		config_path => "$repo/conf/config.json",
		spec_path => File::Spec->catfile($case_dir, 'project.json'),
	);
	my ($one, $other) = $loader->export_data();
	my $out = File::Spec->catdir($tmp, 'go-overlay');
	Tavola::Project::Exporter->new(
		config_path => "$repo/conf/config.json",
		lang => 'go',
		data => [ $one, $other ],
		web_ui => 1,
		asset_root => $repo,
	)->write_dir($out, 1);

	like(_read_text("$out/internal/item/model.go"), qr/custom go model overlay/, 'go model overlay replaces generated model');
	like(_read_text("$out/internal/item/filter.go"), qr/custom go filter overlay/, 'go filter overlay replaces generated filter');
	ok(-s "$out/README.md", 'go generated README exists');
	ok(-s "$out/www/index.html", 'go generated web index exists');
	ok(!-e "$out/www/genelet.js", 'go generated web UI omits PHP/Perl genelet.js helper');
	ok(-s "$out/views/p/error.html", 'go generated public error template exists');
	ok(-s "$out/views/u/login.html", 'go generated protected role login template exists');
	ok(-s "$out/views/p/item/topics.html", 'go generated public action template exists');
}

sub _assert_go_auth_key_compatibility {
	my $go = Tavola::Generator::Go->new(
		_config => { Custom => { USER_domain => 'example.test' } },
		project => {
			Project => 'AuthApp',
			dbtype => 'MySQL',
			dbname => 'authapp',
		},
		roles => [
			{
				name_role => 'g',
				roleid => 1,
				authen => 'google',
				field_id => 'user_id',
				field_login => 'email',
				field_passwd => 'passwd',
				field_firstname => 'firstname',
				field_lastname => 'lastname',
				procedure_name => 'proc_auth_g',
			},
		],
	);
	my $config = $go->config_hash();
	my $issuer = $config->{Roles}->{g}->{Issuers}->{google};
	ok($issuer->{Provider_pars}, 'go config keeps Provider_pars key for Genelet JSON tag');
	ok(!$issuer->{ProviderPars}, 'go config does not emit unsupported ProviderPars key');

	my $manual = {
		Roles => {
			u => {
				Issuers => {
					db => {
						Password_hash => 'passwd_hash',
						In_pars => [ 'email' ],
						Out_pars => [ 'user_id', 'email' ],
					},
				},
			},
		},
	};
	$go->_normalize_config_hash($manual);
	is($manual->{Roles}->{u}->{Issuers}->{db}->{Password_hash}, 'passwd_hash', 'go config keeps Password_hash key for Genelet JSON tag');
	ok(!$manual->{Roles}->{u}->{Issuers}->{db}->{PasswordHash}, 'go config does not emit unsupported PasswordHash key');
	is_deeply($manual->{Roles}->{u}->{Issuers}->{db}->{InPars}, [ 'email' ], 'go config still emits supported InPars key');
	is_deeply($manual->{Roles}->{u}->{Issuers}->{db}->{OutPars}, [ 'user_id', 'email' ], 'go config still emits supported OutPars key');
}

sub _assert_go_overlay_import_guard {
	my $spec = _read_json("$repo/specs/project.template.json");
	$spec->{overlays}->{components}->{item} = { goModelFile => 'overlays/internal/item/model.go' };
	my $err = _error_for(sub {
		Tavola::Project::Spec::Importer->new(spec => $spec)->_reject_go_overlays();
	});
	like($err, qr/Go overlays are supported only by direct JSON generation.*goModelFile/s, 'metadata import rejects Go overlay files before silent loss');

	my $inline = _read_json("$repo/specs/project.template.json");
	$inline->{components}->[0]->{goFilter} = 'package item';
	$err = _error_for(sub {
		Tavola::Project::Spec::Importer->new(spec => $inline)->_reject_go_overlays();
	});
	like($err, qr/Go overlays are supported only by direct JSON generation.*goFilter/s, 'metadata import rejects inline Go overlays before silent loss');
}

sub _assert_go_readme_endpoint_selection {
	my $public_out = _generate('go');
	my $public_readme = _read_text("$public_out/README.md");
	like($public_readme, qr{/example/app\.php/p/json/item\?action=topics}, 'go README uses a public endpoint when available');
	like($public_readme, qr/This endpoint is public\./, 'go README labels public endpoint');

	my $case_dir = File::Spec->catdir($tmp, 'go-readme-protected-case');
	make_path($case_dir);
	my $spec = _read_json("$repo/specs/project.template.json");
	$spec->{components}->[0]->{public} = [];
	_write_text(File::Spec->catfile($case_dir, 'project.json'), encode_json($spec));
	my $loader = Tavola::Project::Spec->new(
		config_path => "$repo/conf/config.json",
		spec_path => File::Spec->catfile($case_dir, 'project.json'),
	);
	my ($one, $other) = $loader->export_data();
	my $out = File::Spec->catdir($tmp, 'go-readme-protected');
	Tavola::Project::Exporter->new(
		config_path => "$repo/conf/config.json",
		lang => 'go',
		data => [ $one, $other ],
		web_ui => 0,
		asset_root => $repo,
	)->write_dir($out, 1);
	my $readme = _read_text("$out/README.md");
	like($readme, qr{/example/app\.php/u/json/item\?action=topics}, 'go README falls back to protected endpoint when no public action exists');
	like($readme, qr/This endpoint requires login/, 'go README labels protected fallback endpoint');
}

sub _component_json_path {
	my ($out, $lang) = @_;
	return "$out/src/item/component.json" if $lang eq 'php';
	return "$out/internal/item/component.json" if $lang eq 'go';
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

sub _read_text {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $text = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return $text;
}

sub _write_text {
	my ($path, $text) = @_;
	open my $fh, '>', $path or die "Cannot open $path: $!";
	print {$fh} $text;
	close $fh or die "Cannot close $path: $!";
	return;
}

sub _error_for {
	my $code = shift;
	my $ok = eval {
		$code->();
		1;
	};
	return '' if $ok;
	return $@ || 'unknown error';
}

sub _sorted {
	my $list = shift || [];
	return [ sort @$list ];
}

sub _go_model_overlay {
	return <<'GO';
package item

import (
	"net/url"

	"github.com/guruperl/genelet"
)

// custom go model overlay
type Model struct {
	genelet.Model
}

func NewModel() *Model {
	model := &Model{}
	model.Initialize(loadComponent())
	return model
}

func (model *Model) Topics(extra url.Values, nextextra url.Values) error {
	return model.Model.Topics(extra, nextextra)
}

func (model *Model) Edit(extra url.Values, nextextra url.Values) error {
	return model.Model.Edit(extra, nextextra)
}

func (model *Model) Insert(extra url.Values, nextextra url.Values) error {
	return model.Model.Insert(extra, nextextra)
}

func (model *Model) Insupd(extra url.Values, nextextra url.Values) error {
	return model.Model.Insupd(extra, nextextra)
}

func (model *Model) Update(extra url.Values, nextextra url.Values) error {
	return model.Model.Update(extra, nextextra)
}

func (model *Model) Delete(extra url.Values, nextextra url.Values) error {
	return model.Model.Delete(extra, nextextra)
}
GO
}

sub _go_filter_overlay {
	return <<'GO';
package item

import (
	"net/url"

	"github.com/guruperl/genelet"
)

// custom go filter overlay
type Filter struct {
	genelet.Filter
}

func NewFilter() *Filter {
	filter := &Filter{}
	filter.Initialize(loadComponent())
	return filter
}

func (filter *Filter) Before(model *Model, extra url.Values, nextextra url.Values) error {
	return filter.Filter.Before(&model.Model, extra, nextextra)
}

func (filter *Filter) After(model *Model) error {
	return filter.Filter.After(&model.Model)
}
GO
}
