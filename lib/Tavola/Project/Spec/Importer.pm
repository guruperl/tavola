package Tavola::Project::Spec::Importer;

use strict;
use warnings;

use DBI;
use JSON qw(decode_json encode_json);
use Tavola::Generator::PHP;
use Tavola::Project::ComponentJSON;
use Tavola::Project::Spec::Paths;

sub new {
	my ($class, %args) = @_;
	return bless {
		spec        => $args{spec},
		config      => $args{config},
		dbh         => $args{dbh},
		files       => $args{files},
		replace     => $args{replace} ? 1 : 0,
		paths       => $args{paths} || Tavola::Project::Spec::Paths->new(config => $args{config}),
		tableids    => {},
		roleids     => {},
		componentids=> {},
		procedures  => {},
	}, $class;
}

sub run {
	my $self = shift;
	$self->{dbh} ||= $self->_connect($self->{config});

	my $dbh = $self->{dbh};
	eval {
		$dbh->begin_work;
		$self->_import;
		$dbh->commit;
		1;
	} or do {
		my $err = $@ || 'unknown import failure';
		eval { $dbh->rollback };
		die $err;
	};

	return;
}

sub _import {
	my $self = shift;
	my $spec = $self->{spec};

	my $memberid = $self->_ensure_owner($spec->{owner});
	if (my $existing = $self->_existing_project($memberid)) {
		die "Owner '$spec->{owner}->{login}' already has project '$existing->{Project}'. Use --replace to recreate it.\n"
			unless $self->{replace};
		$self->{dbh}->do('DELETE FROM user_project WHERE projectid=?', undef, $existing->{projectid});
	}

	my $projectid = $self->_insert_project($memberid, $spec->{project});
	$self->_insert_datasource($projectid, $spec->{datasource});
	$self->_insert_tables($projectid, $spec->{schema}->{tables});
	$self->_insert_procedures($projectid, $spec->{schema}->{procedures});
	$self->_insert_roles($projectid, $spec->{roles});
	$self->_insert_components($projectid, $spec->{components});
	$self->_update_generated_project_code($projectid);

	print "Imported project '$spec->{project}->{name}' for owner '$spec->{owner}->{login}' as projectid $projectid\n";
	return;
}

sub _ensure_owner {
	my ($self, $owner) = @_;
	my $dbh = $self->{dbh};
	my ($memberid) = $dbh->selectrow_array('SELECT memberid FROM member WHERE login=?', undef, $owner->{login});
	return $memberid if $memberid;

	$memberid = $owner->{memberid} || $self->_random_hex_memberid();
	my $passwd = $owner->{password} || $self->_random_hex(16);
	$dbh->do(
		'INSERT INTO member (memberid,typeid,groupid,login,passwd,active,email,firstname,lastname,created) VALUES (?,?,?,?,SHA1(CONCAT(?,?)),?,?,?,?,NOW())',
		undef,
		$memberid, $owner->{typeid}, $memberid, $owner->{login}, $owner->{login}, $passwd,
		'Yes', $owner->{email}, $owner->{firstname}, $owner->{lastname},
	);
	return $memberid;
}

sub _random_hex_memberid {
	my $self = shift;
	my $dbh = $self->{dbh};
	for (1 .. 100) {
		my $id = 100000 + int(rand(900000));
		my ($exists) = $dbh->selectrow_array('SELECT 1 FROM member WHERE memberid=?', undef, $id);
		return $id unless $exists;
	}
	die "Could not allocate a memberid\n";
}

sub _existing_project {
	my ($self, $memberid) = @_;
	return $self->{dbh}->selectrow_hashref('SELECT projectid, Project FROM user_project WHERE memberid=?', undef, $memberid);
}

sub _insert_project {
	my ($self, $memberid, $project) = @_;
	my $dbh = $self->{dbh};
	my $owner = $self->{spec}->{owner};
	my $paths = $self->{paths}->project_paths($project, $owner);

	$dbh->do(
		'INSERT INTO user_project (memberid,ds,Document_root,Project,Server_url,Script,Template,Uploaddir,Pubrole,def_component,def_action,admin_role,admin_user,admin_pass,Log_file,created) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())',
		undef,
		$memberid,
		$project->{ds} || 'remote',
		$paths->{document_root},
		$project->{name},
		$paths->{server_url},
		$project->{script},
		$paths->{template},
		$paths->{upload_dir},
		$project->{publicRole},
		$project->{default}->{component},
		$project->{default}->{action},
		$project->{adminRole} || 'a',
		$project->{adminUser} || 'admin',
		$project->{adminPass} || $self->_random_hex(8),
		$paths->{log_file},
	);
	return $dbh->last_insert_id(undef, undef, 'user_project', 'projectid');
}

sub _insert_datasource {
	my ($self, $projectid, $ds) = @_;
	$self->{dbh}->do(
		'INSERT INTO user_ds (projectid,dbtype,nickname,dbname,host,port,dbuser,dbpass,is_connected,created) VALUES (?,?,?,?,?,?,?,?,?,NOW())',
		undef,
		$projectid, $ds->{type}, $ds->{nickname}, $ds->{database} || $ds->{path}, $ds->{host} || '', $ds->{port} || '',
		$ds->{user} || '', $ds->{password} || '', $ds->{connected} || 'No',
	);
	return;
}

sub _insert_tables {
	my ($self, $projectid, $tables) = @_;
	my $dbh = $self->{dbh};

	for my $table (@$tables) {
		$dbh->do(
			'INSERT INTO user_table (projectid,table_name,current_key,current_id_auto,insert_pars,edit_pars,update_pars,topics_pars,statement,is_tavola,table_comment,created) VALUES (?,?,?,?,?,?,?,?,?,?,?,NOW())',
			undef,
			$projectid,
			$table->{name},
			$table->{primaryKey},
			$table->{autoKey},
			$self->_json($table->{insert} || []),
			$self->_json($table->{edit} || []),
			$self->_json($table->{update} || []),
			$self->_json($table->{topics} || []),
			$self->{files}->statement($table),
			$table->{isTavola} || 0,
			$table->{comment},
		);
		my $tableid = $dbh->last_insert_id(undef, undef, 'user_table', 'tableid');
		$self->{tableids}->{$table->{name}} = $tableid;

		for my $fk (@{$table->{fks} || []}) {
			$dbh->do(
				'INSERT INTO user_table_fk (tableid,FKCOLUMN_NAME,PKTABLE_NAME,PKCOLUMN_NAME) VALUES (?,?,?,?)',
				undef, $tableid, $fk->{column}, $fk->{primaryTable}, $fk->{primaryColumn},
			);
		}
		for my $unique (@{$table->{uniques} || []}) {
			$dbh->do(
				'INSERT INTO user_table_unique (tableid,INDEX_NAME,ORDINAL_POSITION,COLUMN_NAME) VALUES (?,?,?,?)',
				undef, $tableid, $unique->{name}, $unique->{position}, $unique->{column},
			);
		}
		for my $non (@{$table->{nons} || []}) {
			$dbh->do('INSERT INTO user_table_non (tableid,COLUMN_NAME) VALUES (?,?)', undef, $tableid, $non);
		}
	}
	return;
}

sub _insert_procedures {
	my ($self, $projectid, $procedures) = @_;
	my $dbh = $self->{dbh};

	for my $procedure (@$procedures) {
		my $tableid = $procedure->{table} ? $self->{tableids}->{$procedure->{table}} : undef;
		$dbh->do(
			'INSERT INTO user_procedure (projectid,is_tavola,procedure_name,tableid,statement,created) VALUES (?,?,?,?,?,NOW())',
			undef,
			$projectid,
			$procedure->{isTavola} || 0,
			$procedure->{name},
			$tableid,
			$self->{files}->statement($procedure),
		);
		$self->{procedures}->{$procedure->{name}} = {
			tableid => $tableid,
			name => $procedure->{name},
		};
	}
	return;
}

sub _insert_roles {
	my ($self, $projectid, $roles) = @_;
	my $dbh = $self->{dbh};

	for my $role (@$roles) {
		my $fields = $role->{fields};
		my $default = $role->{default} || {};
		my $tableid = $role->{table} ? $self->{tableids}->{$role->{table}} : undef;
		$dbh->do(
			'INSERT INTO user_role (projectid,is_auto,is_admin,name_role,description,authen,tableid,default_component,default_action,field_id,field_login,field_passwd,field_firstname,field_lastname,restriction,created) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())',
			undef,
			$projectid,
			$role->{isAuto} || 0,
			$role->{isAdmin} || 0,
			$role->{name},
			$role->{description},
			$role->{authen},
			$tableid,
			$default->{component},
			$default->{action},
			$fields->{id},
			$fields->{login},
			$fields->{password},
			$fields->{firstname},
			$fields->{lastname},
			$role->{restriction},
		);
		$self->{roleids}->{$role->{name}} = $dbh->last_insert_id(undef, undef, 'user_role', 'roleid');
	}
	return;
}

sub _insert_components {
	my ($self, $projectid, $components) = @_;
	my $dbh = $self->{dbh};

	for my $component (@$components) {
		my $tableid = $self->{tableids}->{$component->{table}};
		my $table = $self->_table_by_id($tableid);
		my $component_json = Tavola::Project::ComponentJSON->new(
			spec => $self->{spec},
			files => $self->{files},
		)->encode($component, $table);
		my $filter = $self->_overlay_text($component, 'filter')
			|| Tavola::Generator::PHP->new(project => { Project => $self->{spec}->{project}->{name} }, component => { name_component => $component->{name} })->filter();
		my $model = $self->_overlay_text($component, 'model')
			|| Tavola::Generator::PHP->new(project => { Project => $self->{spec}->{project}->{name} }, component => { name_component => $component->{name} })->model();

		$dbh->do(
			'INSERT INTO user_component (projectid,name_component,description,tableid,current_key,current_id_auto,current_tables,topics_hash,insert_pars,edit_pars,update_pars,topics_pars,component_json,filter,model,created) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())',
			undef,
			$projectid,
			$component->{name},
			$component->{description},
			$tableid,
			$component->{primaryKey} || $table->{current_key},
			exists $component->{autoKey} ? $component->{autoKey} : $table->{current_id_auto},
			$component->{currentTables} ? $self->_json($component->{currentTables}) : undef,
			$component->{topicsHash} ? $self->_json($component->{topicsHash}) : undef,
			$self->_json($component->{insert} || $table->{insert_pars}),
			$self->_json($component->{edit} || $table->{edit_pars}),
			$self->_json($component->{update} || $table->{update_pars}),
			$self->_json($component->{topics} || $table->{topics_pars}),
			$component_json,
			$filter,
			$model,
		);
		my $componentid = $dbh->last_insert_id(undef, undef, 'user_component', 'componentid');
		$self->{componentids}->{$component->{name}} = $componentid;
		$self->_insert_component_actions($componentid, $component);
	}
	return;
}

sub _table_by_id {
	my ($self, $tableid) = @_;
	my $row = $self->{dbh}->selectrow_hashref(
		'SELECT current_key,current_id_auto,insert_pars,edit_pars,update_pars,topics_pars FROM user_table WHERE tableid=?',
		undef,
		$tableid,
	);
	for my $key (qw(insert_pars edit_pars update_pars topics_pars)) {
		$row->{$key} = decode_json($row->{$key} || '[]');
	}
	return $row;
}

sub _insert_component_actions {
	my ($self, $componentid, $component) = @_;
	my $dbh = $self->{dbh};
	my $public = $self->_crud_set($component->{public});
	if ($public) {
		$dbh->do('INSERT INTO user_action_public (componentid,crud) VALUES (?,?)', undef, $componentid, $public);
	}

	for my $role (keys %{$component->{roles} || {}}) {
		my $action = $component->{roles}->{$role};
		my $crud = ref($action) eq 'HASH' ? $self->_crud_set($action->{crud}) : $self->_crud_set($action);
		next unless $crud;
		$dbh->do(
			'INSERT INTO user_action (componentid,roleid,crud,inkey,inmd5,outkey,outmd5) VALUES (?,?,?,?,?,?,?)',
			undef,
			$componentid,
			$self->{roleids}->{$role},
			$crud,
			ref($action) eq 'HASH' ? @{$action}{qw(inkey inmd5 outkey outmd5)} : (undef, undef, undef, undef),
		);
	}
	return;
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

sub _update_generated_project_code {
	my ($self, $projectid) = @_;
	my $dbh = $self->{dbh};
	my $project = $dbh->selectrow_hashref(
		'SELECT p.*, d.dbtype, d.dbname, d.dbuser, d.dbpass, d.host, d.port FROM user_project p INNER JOIN user_ds d USING (projectid) WHERE p.projectid=?',
		undef,
		$projectid,
	);
	my $roles = $self->_role_config_rows($projectid);
	my $php = Tavola::Generator::PHP->new(
		_config => $self->{config},
		project => $project,
		roles => $roles,
	);

	my $project_overlays = $self->{spec}->{overlays}->{project} || {};
	my $filter = $project_overlays->{filter}
		|| ($project_overlays->{filterFile} ? $self->{files}->read_text($project_overlays->{filterFile}) : undef)
		|| $php->project_filter();
	my $model = $project_overlays->{model}
		|| ($project_overlays->{modelFile} ? $self->{files}->read_text($project_overlays->{modelFile}) : undef)
		|| $php->project_model();

	$dbh->do(
		'UPDATE user_project SET config_json=?, filter=?, model=? WHERE projectid=?',
		undef,
		$php->get_config(),
		$filter,
		$model,
		$projectid,
	);
	return;
}

sub _role_config_rows {
	my ($self, $projectid) = @_;
	return $self->{dbh}->selectall_arrayref(
		'SELECT r.*, p.procedure_name FROM user_role r LEFT JOIN user_procedure p ON (r.tableid=p.tableid) WHERE r.projectid=? ORDER BY r.roleid',
		{ Slice => {} },
		$projectid,
	);
}

sub _connect {
	my ($self, $config) = @_;
	my $db = $config->{Db} || die "Config is missing Db\n";
	die "Config Db must be [dsn,user,password]\n" unless ref($db) eq 'ARRAY' && @$db >= 3;

	my @db = map { $self->_expand_required($_) } @$db;
	return DBI->connect($db[0], $db[1], $db[2], {
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
		mysql_enable_utf8 => 1,
	});
}

sub _expand_required {
	my ($self, $value) = @_;
	if (defined($value) && !ref($value) && $value =~ /\A\$\{([A-Z_][A-Z0-9_]*)\}\z/) {
		my $name = $1;
		die "Missing required environment variable $name\n" unless defined $ENV{$name};
		return $ENV{$name};
	}
	return $value;
}

sub _crud_set {
	my ($self, $actions) = @_;
	return unless $actions;
	my %allowed = map { $_ => 1 } qw(startnew insert edit update delete topics);
	my @actions = ref($actions) eq 'ARRAY' ? @$actions : split /\s*,\s*/, $actions;
	@actions = grep { $allowed{$_} } @actions;
	return @actions ? join(',', @actions) : undef;
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
