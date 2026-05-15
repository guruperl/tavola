use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use JSON qw(decode_json encode_json);
use Test::More;

use Tabilet::Project::APIManifest;
use Tabilet::Project::JSONSchema;
use Tabilet::Project::OpenAPI;

my $repo = abs_path("$Bin/..");
my $manifest = Tabilet::Project::APIManifest->new(one => _synthetic_project())->manifest();
my $schema = _read_json("$repo/docs/api.schema.json");
my @errors = Tabilet::Project::JSONSchema->new(schema => $schema)->validate($manifest);
is_deeply(\@errors, [], 'custom action api manifest matches schema');

my ($vehicle) = grep { $_->{name} eq 'vehicle' } @{$manifest->{components}};
my @action_names = map { $_->{name} } @{$vehicle->{actions}};
is_deeply(\@action_names, [ qw(topics insert makes years) ], 'custom actions follow built-in actions in sorted order');

my %actions = map { $_->{name} => $_ } @{$vehicle->{actions}};
ok($actions{years}, 'custom years action appears in api manifest');
is_deeply($actions{years}->{allowed_groups}, [ 'u' ], 'custom years action keeps groups');
is_deeply($actions{years}->{request_params}, [], 'custom years action has no inferred request params');
ok(!$actions{years}->{public}, 'custom years action is protected');
ok(!$actions{history}, 'custom action without groups is omitted');

my $docs = Tabilet::Project::APIManifest->new(one => _synthetic_project())->docs($manifest);
like($docs, qr/\| `vehicle` \| `years` \| `u` \|  \| `\/example\/app\.php\/u\/json\/vehicle\?action=years` \|/, 'docs include custom action component row');
like($docs, qr/\| `vehicle` \| `years` \|  \| `\/example\/app\.php\/u\/json\/vehicle\?action=years` \|/, 'docs include custom action protected example');

my $openapi = Tabilet::Project::OpenAPI->new(manifest => $manifest)->document();
my $vehicle_path = $openapi->{paths}->{'/example/app.php/{role}/json/vehicle'}->{get};
is_deeply($vehicle_path->{parameters}->[1]->{schema}->{enum}, [ qw(topics insert makes years) ], 'OpenAPI action enum includes custom actions');
my %openapi_actions = map { $_->{name} => $_ } @{$vehicle_path->{'x-tavola-actions'}};
ok($openapi_actions{years}, 'OpenAPI extension includes custom action');
is_deeply($openapi_actions{years}->{request_params}, [], 'OpenAPI custom action has empty request params');

is(
	$openapi->{paths}->{'/example/app.php/{role}/json/a-b'}->{get}->{operationId},
	'tavolaA_bAction',
	'first sanitized OpenAPI operationId is stable',
);
is(
	$openapi->{paths}->{'/example/app.php/{role}/json/a_b'}->{get}->{operationId},
	'tavolaA_bAction_2',
	'colliding sanitized OpenAPI operationId gets deterministic suffix',
);

done_testing();

sub _synthetic_project {
	my $component_json = {
		actions => {
			years => { groups => [ 'u' ] },
			makes => { groups => [ 'p' ] },
			history => {},
			insert => { groups => [ 'u' ] },
			topics => { groups => [ 'p', 'u' ] },
		},
		current_table => 'vehicle',
		current_key => 'vehicle_id',
		current_id_auto => 'vehicle_id',
		insert_pars => [ qw(make year) ],
		edit_pars => [ qw(vehicle_id make year) ],
		update_pars => [ qw(vehicle_id make year) ],
		topics_pars => [ qw(vehicle_id make year) ],
	};
	my $colliding_component_json = {
		actions => {
			topics => { groups => [ 'p' ] },
		},
		current_table => 'collision',
		current_key => 'collision_id',
		insert_pars => [],
		edit_pars => [],
		update_pars => [],
		topics_pars => [ 'collision_id' ],
	};

	return {
		Project => 'ExampleApp',
		Script => '/example/app.php',
		Pubrole => 'p',
		def_component => 'vehicle',
		def_action => 'topics',
		role_topics => [
			{
				name_role => 'u',
				authen => 'db',
				description => 'User',
				is_admin => 0,
				is_auto => 1,
				default_component => 'vehicle',
				default_action => 'topics',
				field_id => 'user_id',
				field_login => 'email',
				field_passwd => 'passwd',
				field_firstname => 'firstname',
				field_lastname => 'lastname',
				restriction => undef,
				procedure_name => 'proc_example_u',
			},
		],
		component_topics => [
			{
				name_component => 'vehicle',
				description => 'Vehicles',
				component_json => encode_json($component_json),
			},
			{
				name_component => 'a-b',
				description => 'Collision A',
				component_json => encode_json($colliding_component_json),
			},
			{
				name_component => 'a_b',
				description => 'Collision B',
				component_json => encode_json($colliding_component_json),
			},
		],
	};
}

sub _read_json {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $json = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return decode_json($json);
}
