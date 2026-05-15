package Tabilet::Project::OpenAPI;

use strict;
use warnings;

use JSON;

sub new {
	my ($class, %args) = @_;
	return bless {
		manifest => $args{manifest},
	}, $class;
}

sub encode {
	my $self = shift;
	return JSON->new->canonical->pretty->encode($self->document());
}

sub document {
	my $self = shift;
	my $manifest = $self->{manifest};
	my $project = $manifest->{project};
	my $script = $project->{script};
	my @roles = map { $_->{name} } @{$manifest->{roles} || []};
	my @protected = grep { $_->{login} } @{$manifest->{roles} || []};

	my $paths = {};
	if (@protected) {
		$paths->{"$script/{role}/json/login"} = $self->_login_path(\@protected);
	}
	my %operation_ids;
	for my $component (@{$manifest->{components} || []}) {
		$paths->{"$script/{role}/json/$component->{name}"} = $self->_component_path($component, \@roles, \%operation_ids);
	}

	return {
		openapi => '3.0.3',
		info => {
			title => "$project->{name} API",
			version => '1.0.0',
			description => 'Derived from Tavola api.json. Tavola action details are preserved in x-tavola-* extensions.',
		},
		paths => $paths,
		components => {
			schemas => {
				TavolaResponse => {
					type => 'object',
					additionalProperties => JSON::true,
				},
			},
		},
		'x-tavola-source' => 'api.json',
		'x-tavola-endpoint-pattern' => $manifest->{endpoint_pattern},
	};
}

sub _login_path {
	my ($self, $roles) = @_;
	my @role_names = map { $_->{name} } @$roles;
	my %credentials;
	for my $role (@$roles) {
		$credentials{$_} ||= { type => 'string' } for @{$role->{login}->{credentials} || []};
	}

	return {
		post => {
			summary => 'Log in as a protected role',
			operationId => 'tavolaLogin',
			parameters => [
				{
					name => 'role',
					in => 'path',
					required => JSON::true,
					schema => { type => 'string', enum => \@role_names },
				},
			],
			requestBody => {
				required => JSON::true,
				content => {
					'application/x-www-form-urlencoded' => {
						schema => {
							type => 'object',
							properties => \%credentials,
						},
					},
				},
			},
			responses => $self->_responses(),
			'x-tavola-logins' => [
				map {
					{
						role => $_->{name},
						method => $_->{login}->{method},
						credentials => $_->{login}->{credentials},
						sql => $_->{login}->{sql},
						fields => $_->{fields},
					}
				} @$roles
			],
		},
	};
}

sub _component_path {
	my ($self, $component, $roles, $operation_ids) = @_;
	my @actions = map { $_->{name} } @{$component->{actions} || []};
	my %params;
	for my $action (@{$component->{actions} || []}) {
		$params{$_} ||= { type => 'string' } for @{$action->{request_params} || []};
	}

	return {
		get => {
			summary => "$component->{name} component action",
			operationId => _operation_id($component->{name}, $operation_ids),
			parameters => [
				{
					name => 'role',
					in => 'path',
					required => JSON::true,
					schema => { type => 'string', enum => $roles },
				},
				{
					name => 'action',
					in => 'query',
					required => JSON::true,
					schema => { type => 'string', enum => \@actions },
				},
				map {
					{
						name => $_,
						in => 'query',
						required => JSON::false,
						schema => $params{$_},
					}
				} sort keys %params,
			],
			responses => $self->_responses(),
			'x-tavola-component' => {
				name => $component->{name},
				table => $component->{table},
				primary_key => $component->{primary_key},
			},
			'x-tavola-actions' => [
				map {
					{
						name => $_->{name},
						allowed_groups => $_->{allowed_groups},
						public => $_->{public},
						options => $_->{options},
						request_params => $_->{request_params},
						examples => $_->{examples},
					}
				} @{$component->{actions} || []}
			],
		},
	};
}

sub _responses {
	return {
		'200' => {
			description => 'Tavola JSON response',
			content => {
				'application/json' => {
					schema => {
						'$ref' => '#/components/schemas/TavolaResponse',
					},
				},
			},
		},
	};
}

sub _operation_id {
	my ($component, $seen) = @_;
	$component =~ s/[^A-Za-z0-9_]+/_/g;
	my $base = 'tavola' . ucfirst($component) . 'Action';
	my $count = ++$seen->{$base};
	return $count == 1 ? $base : "${base}_$count";
}

1;
