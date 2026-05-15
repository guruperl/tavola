package Tabilet::Project::Spec::MetadataBuilder;

use strict;
use warnings;

use JSON qw(decode_json encode_json);
use Tabilet::Generator::PHP;
use Tabilet::Project::ComponentJSON;
use Tabilet::Project::Spec::Paths;

sub new {
	my ($class, %args) = @_;
	return bless {
		spec  => $args{spec},
		config=> $args{config} || {},
		files => $args{files},
		paths => $args{paths} || Tabilet::Project::Spec::Paths->new(config => $args{config}),
	}, $class;
}

sub build {
	my $self = shift;
	my $spec = $self->{spec};

	my $memberid = $spec->{owner}->{memberid} || 0;
	my $projectid = 1;
	my $paths = $self->{paths}->project_paths($spec->{project}, $spec->{owner});

	my $one = {
		projectid      => $projectid,
		memberid       => $memberid,
		ds             => $spec->{project}->{ds} || 'remote',
		Document_root  => $paths->{document_root},
		Project        => $spec->{project}->{name},
		Server_url     => $paths->{server_url},
		Script         => $spec->{project}->{script},
		Template       => $paths->{template},
		Uploaddir      => $paths->{upload_dir},
		Pubrole        => $spec->{project}->{publicRole},
		def_component  => $spec->{project}->{default}->{component},
		def_action     => $spec->{project}->{default}->{action},
		admin_role     => $spec->{project}->{adminRole} || 'a',
		admin_user     => $spec->{project}->{adminUser} || 'admin',
		admin_pass     => $spec->{project}->{adminPass} || $self->_random_hex(8),
		Log_file       => $paths->{log_file},
		dbtype         => $spec->{datasource}->{type},
		dbname         => $spec->{datasource}->{database} || $spec->{datasource}->{path},
		dbuser         => $spec->{datasource}->{user} || '',
		dbpass         => $spec->{datasource}->{password} || '',
		host           => $spec->{datasource}->{host} || '',
		port           => $spec->{datasource}->{port} || '',
	};

	my (%tables_by_name, %tables_by_id, %procedures_by_table);
	my $tableid = 1;
	for my $table (@{$spec->{schema}->{tables}}) {
		my $row = {
			tableid         => $tableid++,
			projectid       => $projectid,
			table_name      => $table->{name},
			current_key     => $table->{primaryKey},
			current_id_auto => $table->{autoKey},
			insert_pars     => $self->_json($table->{insert} || []),
			edit_pars       => $self->_json($table->{edit} || []),
			update_pars     => $self->_json($table->{update} || []),
			topics_pars     => $self->_json($table->{topics} || []),
			statement       => $self->{files}->statement($table),
			is_tabilet      => $table->{isTabilet} || 0,
			table_comment   => $table->{comment},
		};
		push @{$one->{table_topics}}, $row;
		$tables_by_name{$table->{name}} = $row;
		$tables_by_id{$row->{tableid}} = $row;
	}

	my $procedureid = 1;
	for my $procedure (@{$spec->{schema}->{procedures}}) {
		my $table = $procedure->{table} ? $tables_by_name{$procedure->{table}} : undef;
		my $row = {
			procedureid    => $procedureid++,
			projectid      => $projectid,
			procedure_name => $procedure->{name},
			statement      => $self->{files}->statement($procedure),
			tableid        => $table ? $table->{tableid} : undef,
			is_tabilet     => $procedure->{isTabilet} || 0,
		};
		push @{$one->{stored_topics}}, $row;
		$procedures_by_table{$row->{tableid}} = $row if $row->{tableid};
	}

	my %roles_by_name;
	my $roleid = 1;
	for my $role (@{$spec->{roles}}) {
		my $fields = $role->{fields};
		my $default = $role->{default} || {};
		my $table = $role->{table} ? $tables_by_name{$role->{table}} : undef;
		my $row = {
			roleid            => $roleid++,
			projectid         => $projectid,
			name_role         => $role->{name},
			description       => $role->{description},
			authen            => $role->{authen},
			is_admin          => $role->{isAdmin} || 0,
			is_auto           => $role->{isAuto} || 0,
			tableid           => $table ? $table->{tableid} : undef,
			default_component => $default->{component},
			default_action    => $default->{action},
			field_id          => $fields->{id},
			field_login       => $fields->{login},
			field_passwd      => $fields->{password},
			field_firstname   => $fields->{firstname},
			field_lastname    => $fields->{lastname},
			restriction       => $role->{restriction},
			procedure_name    => $table && $procedures_by_table{$table->{tableid}} ? $procedures_by_table{$table->{tableid}}->{procedure_name} : undef,
		};
		push @{$one->{role_topics}}, $row;
		$roles_by_name{$role->{name}} = $row;
	}

	my @component_actions;
	my $componentid = 1;
	for my $component (@{$spec->{components}}) {
		my $table = $tables_by_name{$component->{table}};
		my $table_for_json = {
			current_key     => $table->{current_key},
			current_id_auto => $table->{current_id_auto},
			insert_pars     => decode_json($table->{insert_pars} || '[]'),
			edit_pars       => decode_json($table->{edit_pars} || '[]'),
			update_pars     => decode_json($table->{update_pars} || '[]'),
			topics_pars     => decode_json($table->{topics_pars} || '[]'),
		};
		my $component_json = Tabilet::Project::ComponentJSON->new(
			spec => $self->{spec},
			files => $self->{files},
		)->encode($component, $table_for_json);
		my $filter = $self->_overlay_text($component, 'filter')
			|| Tabilet::Generator::PHP->new(project => { Project => $spec->{project}->{name} }, component => { name_component => $component->{name} })->filter();
		my $model = $self->_overlay_text($component, 'model')
			|| Tabilet::Generator::PHP->new(project => { Project => $spec->{project}->{name} }, component => { name_component => $component->{name} })->model();

		my $row = {
			componentid     => $componentid++,
			projectid       => $projectid,
			name_component => $component->{name},
			description    => $component->{description},
			tableid        => $table->{tableid},
			table_name     => $component->{table},
			current_key    => $component->{primaryKey} || $table->{current_key},
			current_id_auto=> exists $component->{autoKey} ? $component->{autoKey} : $table->{current_id_auto},
			current_tables => $component->{currentTables} ? $self->_json($component->{currentTables}) : undef,
			topics_hash    => $component->{topicsHash} ? $self->_json($component->{topicsHash}) : undef,
			insert_pars    => $self->_json($component->{insert} || decode_json($table->{insert_pars} || '[]')),
			edit_pars      => $self->_json($component->{edit} || decode_json($table->{edit_pars} || '[]')),
			update_pars    => $self->_json($component->{update} || decode_json($table->{update_pars} || '[]')),
			topics_pars    => $self->_json($component->{topics} || decode_json($table->{topics_pars} || '[]')),
			component_json => $component_json,
			filter         => $filter,
			model          => $model,
		};
		push @{$one->{component_topics}}, $row;

		if (my $crud = $self->_crud_set($component->{public})) {
			my $acl = $self->_acl_row($row, { crud => $crud });
			push @{$one->{role_pub_acl}}, $acl;
			push @component_actions, { component => $row, role => undef, action => $acl };
		}
		for my $role_name (sort keys %{$component->{roles} || {}}) {
			my $action = $component->{roles}->{$role_name};
			my $crud = ref($action) eq 'HASH' ? $self->_crud_set($action->{crud}) : $self->_crud_set($action);
			next unless $crud;
			my $role = $roles_by_name{$role_name};
			my $acl = $self->_acl_row($row, {
				ref($action) eq 'HASH' ? %$action : (),
				crud      => $crud,
				roleid    => $role->{roleid},
				name_role => $role->{name_role},
				field_id  => $role->{field_id},
			});
			push @{$one->{role_role_acl}}, $acl;
			push @component_actions, { component => $row, role => $role, action => $acl };
		}
	}

	$one->{table_topics} ||= [];
	$one->{stored_topics} ||= [];
	$one->{role_topics} ||= [];
	$one->{component_topics} ||= [];
	$one->{role_pub_acl} ||= [];
	$one->{role_role_acl} ||= [];

	my $php = Tabilet::Generator::PHP->new(
		_config => $self->{config} || {},
		project => $one,
		roles   => $one->{role_topics},
	);
	my $project_overlays = $spec->{overlays}->{project} || {};
	$one->{config_json} = $php->get_config();
	$one->{filter} = $project_overlays->{filter}
		|| ($project_overlays->{filterFile} ? $self->{files}->read_text($project_overlays->{filterFile}) : undef)
		|| $php->project_filter();
	$one->{model} = $project_overlays->{model}
		|| ($project_overlays->{modelFile} ? $self->{files}->read_text($project_overlays->{modelFile}) : undef)
		|| $php->project_model();

	my $other = {
		p_list => [
			map {
				{
					name_component => $_->{component}->{name_component},
					action => $self->_landing_action($_->{action}->{crud}, 1),
				}
			} grep { !$_->{role} } @component_actions
		],
		a_list => [
			map { { name_component => $_->{name_component} } } @{$one->{component_topics}}
		],
		r_list => $self->_role_landing_rows(\@component_actions, \%tables_by_id),
	};

	return ($one, $other);
}

sub _acl_row {
	my ($self, $component, $values) = @_;
	return {
		%$values,
		componentid    => $component->{componentid},
		name_component=> $component->{name_component},
		current_key    => $component->{current_key},
		insert_pars    => $component->{insert_pars},
		edit_pars      => $component->{edit_pars},
		update_pars    => $component->{update_pars},
		topics_pars    => $component->{topics_pars},
	};
}

sub _landing_action {
	my ($self, $crud, $public) = @_;
	my %has = map { $_ => 1 } split(',', $crud || '', -1);
	return 'topics' if $has{topics};
	return 'startnew' if $has{startnew};
	return $public ? '' : ($has{edit} ? 'edit' : '');
}

sub _role_landing_rows {
	my ($self, $actions, $tables_by_id) = @_;
	my @rows;
	for my $item (@$actions) {
		my $role = $item->{role} or next;
		next if $role->{name_role} eq 'a';
		my $role_table = $role->{tableid} ? $tables_by_id->{$role->{tableid}} : undef;
		next unless $role_table;
		my $component = $item->{component};
		my $action = $item->{action};
		my %has = map { $_ => 1 } split(',', $action->{crud} || '', -1);
		my ($level, $landing);
		if ($role->{tableid} && $role->{tableid} == $component->{tableid} && ($has{topics} || $has{startnew} || $has{edit})) {
			$level = 1;
			$landing = $has{edit} ? 'edit' : ($has{topics} ? 'topics' : 'startnew');
		} elsif (($action->{inkey} || '') eq ($role_table->{current_key} || '') && ($has{topics} || $has{startnew})) {
			$level = 2;
			$landing = $has{topics} ? 'topics' : 'startnew';
		} elsif ((!$action->{inkey}) && $has{topics}) {
			$level = 3;
			$landing = 'topics';
		} else {
			next;
		}
		push @rows, {
			roleid            => $role->{roleid},
			name_role         => $role->{name_role},
			default_component => $role->{default_component},
			default_action    => $role->{default_action},
			name_component    => $component->{name_component},
			level             => $level,
			action            => $landing,
			is_edit           => $has{edit} ? 1 : 0,
			is_topics         => $has{topics} ? 1 : 0,
			is_startnew       => $has{startnew} ? 1 : 0,
		};
	}
	return [sort { $a->{name_component} cmp $b->{name_component} || $a->{level} <=> $b->{level} } @rows];
}

sub _crud_set {
	my ($self, $actions) = @_;
	return unless $actions;
	my %allowed = map { $_ => 1 } qw(startnew insert edit update delete topics);
	my @actions = ref($actions) eq 'ARRAY' ? @$actions : split /\s*,\s*/, $actions;
	@actions = grep { $allowed{$_} } @actions;
	return @actions ? join(',', @actions) : undef;
}

sub _overlay_text {
	my ($self, $component, $kind) = @_;
	return $component->{$kind} if $component->{$kind};
	return $self->{files}->read_text($component->{"${kind}File"}) if $component->{"${kind}File"};

	my $overlays = $self->{spec}->{overlays}->{components} || {};
	my $overlay = $overlays->{$component->{name}} || {};
	return $overlay->{$kind} if $overlay->{$kind};
	return $self->{files}->read_text($overlay->{"${kind}File"}) if $overlay->{"${kind}File"};
	return;
}

sub _json {
	my ($self, $value) = @_;
	return encode_json($value);
}

sub _random_hex {
	my ($self, $len) = @_;
	my @chars = ('0' .. '9', 'a' .. 'f');
	my $out = '';
	$out .= $chars[int(rand(@chars))] for 1 .. $len;
	return $out;
}

1;
