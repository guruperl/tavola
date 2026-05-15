package Tabilet::Project::APIManifest;

use strict;
use warnings;

use JSON qw(decode_json);

sub new {
	my ($class, %args) = @_;
	return bless {
		one => $args{one},
		other => $args{other} || {},
	}, $class;
}

sub encode {
	my $self = shift;
	return $self->_json->encode($self->manifest());
}

sub manifest {
	my $self = shift;
	my $one = $self->{one};
	my $public = $one->{Pubrole};
	my $script = $one->{Script};

	my @roles = (
		{
			name => $public,
			public => JSON::true,
			auth_required => JSON::false,
			default => {
				component => $one->{def_component},
				action => $one->{def_action},
			},
		},
		map { $self->_role_manifest($_) } @{$one->{role_topics} || []},
	);

	my @components = map { $self->_component_manifest($_, $script, $public) } @{$one->{component_topics} || []};

	return {
		format => 'tabilet-api-manifest',
		version => 1,
		project => {
			name => $one->{Project},
			script => $script,
			public_role => $public,
			default => {
				component => $one->{def_component},
				action => $one->{def_action},
			},
		},
		endpoint_pattern => '<script>/<role>/<tag>/<component>?action=<action>',
		auth_requirements => {
			public_role => $public,
			protected_roles => [ map { $_->{name_role} } @{$one->{role_topics} || []} ],
			login_endpoint_pattern => '<script>/<role>/json/login',
			session_effect => 'Successful login sets the role session/cookie used by later protected action calls.',
		},
		roles => \@roles,
		components => \@components,
	};
}

sub docs {
	my $self = shift;
	my $manifest = shift || $self->manifest();
	my $project = $manifest->{project};
	my $script = $project->{script};
	my @lines;

	push @lines, "# $project->{name} API";
	push @lines, "";
	push @lines, "Endpoint pattern:";
	push @lines, "";
	push @lines, "```text";
	push @lines, "$manifest->{endpoint_pattern}";
	push @lines, "```";
	push @lines, "";
	push @lines, "Use `json` for API responses and `html` for server-rendered views when templates are present.";
	push @lines, "";
	push @lines, "## Roles";
	push @lines, "";
	push @lines, "| Role | Auth | Default | Login |";
	push @lines, "| --- | --- | --- | --- |";
	for my $role (@{$manifest->{roles}}) {
		my $auth = $role->{auth_required} ? 'required' : 'public';
		my $default = $role->{default} ? "$role->{default}->{component}.$role->{default}->{action}" : '';
		my $login = $role->{login} ? "`$role->{login}->{method}` via `$role->{login}->{endpoint}`" : '';
		push @lines, "| `$role->{name}` | $auth | `$default` | $login |";
	}
	push @lines, "";
	push @lines, "## Login";
	push @lines, "";
	push @lines, "Public role `$project->{public_role}` can call public component actions without a login.";
	push @lines, "A protected role logs in at `<script>/<role>/json/login`, then calls protected component actions with the session/cookie returned by the generated app.";
	for my $role (@{$manifest->{roles}}) {
		next unless $role->{login};
		my $fields = join(', ', map { "`$_`" } @{$role->{login}->{credentials} || []});
		push @lines, "";
		push @lines, "### Role `$role->{name}` Login";
		push @lines, "";
		push @lines, "- Endpoint: `$role->{login}->{endpoint}`";
		push @lines, "- Method: `$role->{login}->{method}`";
		push @lines, "- Request parameters: $fields";
		push @lines, "- Login procedure: `" . ($role->{login}->{sql} || '') . "`";
		push @lines, "";
		push @lines, "| Role Field | Runtime Value |";
		push @lines, "| --- | --- |";
		for my $field (qw(id login password firstname lastname)) {
			my $value = defined $role->{fields}->{$field} ? $role->{fields}->{$field} : '';
			push @lines, "| `$field` | `$value` |";
		}
		push @lines, "";
		push @lines, "Login request:";
		push @lines, "";
		push @lines, "```text";
		push @lines, $self->_login_request_example($role);
		push @lines, "```";
		my @protected = $self->_protected_actions($manifest, $role->{name});
		if (@protected) {
			push @lines, "";
			push @lines, "After login, call protected actions with the returned session/cookie:";
			push @lines, "";
			push @lines, "| Component | Action | Request Params | JSON Example |";
			push @lines, "| --- | --- | --- | --- |";
			for my $item (@protected) {
				my $params = @{$item->{action}->{request_params} || []}
					? join(', ', map { "`$_`" } @{$item->{action}->{request_params}})
					: '';
				my $example = $self->_example($script, $role->{name}, 'json', $item->{component}, $item->{action}->{name});
				push @lines, "| `$item->{component}` | `$item->{action}->{name}` | $params | `$example` |";
			}
		}
	}
	push @lines, "";
	push @lines, "## Components";
	push @lines, "";
	push @lines, "| Component | Action | Groups | Request Params | JSON Example | HTML Example |";
	push @lines, "| --- | --- | --- | --- | --- | --- |";
	for my $component (@{$manifest->{components}}) {
		for my $action (@{$component->{actions}}) {
			my $groups = join(', ', map { "`$_`" } @{$action->{allowed_groups} || []});
			my $params = @{$action->{request_params} || []}
				? join(', ', map { "`$_`" } @{$action->{request_params}})
				: '';
			push @lines, "| `$component->{name}` | `$action->{name}` | $groups | $params | `$action->{examples}->{json}` | `$action->{examples}->{html}` |";
		}
	}
	push @lines, "";
	push @lines, "The primary machine-readable contract is generated at `api.json`; a derived OpenAPI document is generated at `openapi.json`.";
	push @lines, "";

	return join("\n", @lines);
}

sub _role_manifest {
	my ($self, $role) = @_;
	my $out = {
		name => $role->{name_role},
		public => JSON::false,
		auth_required => JSON::true,
		authen => $role->{authen},
		description => $role->{description},
		is_admin => $role->{is_admin} ? JSON::true : JSON::false,
		is_auto => $role->{is_auto} ? JSON::true : JSON::false,
		default => {
			component => $role->{default_component},
			action => $role->{default_action},
		},
		fields => {
			id => $role->{field_id},
			login => $role->{field_login},
			password => $role->{field_passwd},
			firstname => $role->{field_firstname},
			lastname => $role->{field_lastname},
		},
		restriction => $role->{restriction},
	};
	$out->{login} = {
		method => $role->{authen} || 'db',
		endpoint => $self->{one}->{Script} . "/$role->{name_role}/json/login",
		credentials => [ grep { defined && length } ($role->{field_login}, $role->{field_passwd}) ],
		sql => $role->{procedure_name},
	};
	return $out;
}

sub _component_manifest {
	my ($self, $component, $script, $public) = @_;
	my $json = decode_json($component->{component_json});
	my @actions;
	for my $name ($self->_action_names($json->{actions} || {})) {
		my $action = $json->{actions}->{$name} || {};
		my $groups = $action->{groups} || [];
		next unless @$groups;
		push @actions, {
			name => $name,
			allowed_groups => $groups,
			public => (grep { $_ eq $public } @$groups) ? JSON::true : JSON::false,
			options => $action->{options} || [],
			request_params => $self->_request_params($name, $json),
			primary_key => $json->{current_key},
			examples => {
				json => $self->_example($script, $groups->[0], 'json', $component->{name_component}, $name),
				html => $self->_example($script, $groups->[0], 'html', $component->{name_component}, $name),
			},
		};
	}
	return {
		name => $component->{name_component},
		description => $component->{description},
		table => $json->{current_table},
		primary_key => $json->{current_key},
		current_id_auto => $json->{current_id_auto},
		actions => \@actions,
	};
}

sub _action_names {
	my ($self, $actions) = @_;
	my @standard = qw(topics startnew insert edit update delete);
	my %standard = map { $_ => 1 } @standard;
	my @custom = grep { !$standard{$_} } sort keys %$actions;
	return ((grep { exists $actions->{$_} } @standard), @custom);
}

sub _request_params {
	my ($self, $action, $json) = @_;
	return [] if $action eq 'startnew';
	return $json->{insert_pars} || [] if $action eq 'insert';
	return $json->{edit_pars} || [] if $action eq 'edit';
	return $json->{update_pars} || [] if $action eq 'update';
	return $json->{topics_pars} || [] if $action eq 'topics';
	return [ $json->{current_key} ] if $action eq 'delete' && $json->{current_key};
	return [];
}

sub _example {
	my ($self, $script, $role, $tag, $component, $action) = @_;
	return "$script/$role/$tag/$component?action=$action";
}

sub _login_request_example {
	my ($self, $role) = @_;
	my @params = map { "$_=<$_>" } @{$role->{login}->{credentials} || []};
	return $role->{login}->{endpoint} . (@params ? '?' . join('&', @params) : '');
}

sub _protected_actions {
	my ($self, $manifest, $role_name) = @_;
	my @items;
	for my $component (@{$manifest->{components} || []}) {
		for my $action (@{$component->{actions} || []}) {
			next unless grep { $_ eq $role_name } @{$action->{allowed_groups} || []};
			push @items, {
				component => $component->{name},
				action => $action,
			};
		}
	}
	return @items;
}

sub _json {
	return JSON->new->canonical->pretty;
}

1;
