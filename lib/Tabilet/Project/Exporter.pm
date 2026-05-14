package Tabilet::Project::Exporter;

use strict;
use warnings;

use Archive::Tar;
use Cwd qw(getcwd);
use DBI;
use File::Path qw(make_path remove_tree);
use File::Spec;
use JSON qw(decode_json);
use Tabilet::Generator::PHP;
use Tabilet::Generator::Perl;
use Tabilet::Template::Base;
use Tabilet::Template::Role;

sub new {
	my ($class, %args) = @_;
	return bless {
		config_path => $args{config_path},
		config      => $args{config},
		dbh         => $args{dbh},
		projectid   => $args{projectid},
		owner       => $args{owner},
		project     => $args{project},
		lang        => lc($args{lang} || 'php'),
		data        => $args{data},
		asset_root  => $args{asset_root} || '.',
		logger      => $args{logger},
	}, $class;
}

sub export_tar {
	my $self = shift;
	my $tar = Archive::Tar->new;
	my $err = $self->add_to_tar($tar);
	die $self->_error_message($err) if $err;
	return $tar;
}

sub add_to_tar {
	my ($self, $tar, $form) = @_;
	my ($one, $other) = $form ? $self->_from_form($form) : $self->{data} ? @{$self->{data}} : $self->_load_export_data();

	return 3007 unless ($one->{def_component} && $one->{def_action});
	for my $role (@{$one->{role_topics}}) {
		return [3008, $role->{name_role}] unless ($role->{default_component} && $role->{default_action});
	}

	$tar->add_data('www/genelet.js', $self->_read_asset('www/genelet.js'));

	my $str = '';
	for my $hash (@{$one->{table_topics}}) {
		$str .= "\nDROP TABLE IF EXISTS " . $hash->{table_name} . ";\n" . $hash->{statement} . ";\n\n";
	}
	for my $hash (@{$one->{stored_topics}}) {
		$str .= "\nDROP PROCEDURE IF EXISTS " . $hash->{procedure_name} . ";\n"
			. "DELIMITER //\n"
			. $hash->{statement} . "//\n"
			. "DELIMITER ;\n\n";
	}

	my $project = {};
	$project->{$_} = $one->{$_} for (qw(memberid filter model config_json Document_root Project Server_url Script Template Uploaddir Pubrole def_component def_action ds));
	$project->{$_} = $one->{$_} for (qw(dbtype dbname dbuser dbpass host port Log_file));
	my $generator = $self->_generator(
		project    => $project,
		logger     => $self->{logger},
		_config    => $self->_config(),
		components => [map { $_->{name_component} } @{$one->{component_topics}}],
		lists      => $one->{role_topics},
	);

	$tar->add_data('conf/init.sql', $str);
	$tar->add_data('www/index.html', Tabilet::Template::Base::index($one->{def_component}, $one->{def_action}, $other->{p_list}, $other->{a_list}, $other->{r_list}));
	$tar->add_data('logs/debug.log', '');
	$tar->chmod('logs/debug.log', '777');
	$tar->add_data('conf/config.json', $one->{config_json});
	$self->{lang} eq 'php'
		? $self->_add_php_project($tar, $one, $project, $generator)
		: $self->_add_perl_project($tar, $one, $project, $generator);

	my ($html, $output, $twig) = Tabilet::Template::Role::vues($one, $self->{logger});
	$tar->add_data('www/app.html', Tabilet::Template::Base::app($html, 'p', $one->{def_component}, $one->{def_action}));
	$tar->add_data("views/$_/error.html", '<html><body>{{error_code}}:{{error_string}}</body></html>') for (sort keys %$output);
	for my $role (sort keys %$output) {
		my $item = $output->{$role};
		for my $comp (sort keys %$item) {
			my $obj = $item->{$comp};
			my $web = $twig->{$role}->{$comp};
			if (grep { $comp eq $_ } qw(header footer login)) {
				$tar->add_data("www/$role/$comp.vue", $obj);
				$tar->add_data("views/$role/$comp.html", $web);
			} else {
				for my $k (sort keys %$obj) {
					$tar->add_data("www/$role/$comp/$k.vue", $obj->{$k}) if $obj->{$k};
				}
				for my $k (sort keys %$web) {
					$tar->add_data("views/$role/$comp/$k.html", $web->{$k}) if $web->{$k};
				}
			}
		}
	}
	return;
}

sub _add_php_project {
	my ($self, $tar, $one, $project, $php) = @_;

	$tar->add_data('composer.json', $php->composer());
	$tar->add_data('www/app.php', $php->app());
	$tar->add_data('src/Application.php', $php->application());
	$tar->add_data('src/Beacon.php', $php->project_beacon());
	$tar->add_data('src/Filter.php', $one->{filter});
	$tar->add_data('src/Model.php', $one->{model});
	for my $item (@{$one->{component_topics}}) {
		my $c = $item->{name_component};
		my $comp_php = $self->_generator(
			project   => $project,
			logger    => $self->{logger},
			_config   => $self->_config(),
			component => $item,
		);
		$tar->add_data("src/$c/component.json", $item->{component_json});
		$tar->add_data("src/$c/Beacon.php", $comp_php->beacon());
		$tar->add_data("src/$c/Filter.php", $item->{filter});
		$tar->add_data("src/$c/Model.php", $item->{model});
	}
	return;
}

sub _add_perl_project {
	my ($self, $tar, $one, $project, $perl) = @_;

	my $name = ucfirst $one->{Project};
	$tar->add_data('script/app', $perl->app('conf/config.json', 'lib'));
	$tar->chmod('script/app', '755');
	$tar->add_data("lib/$name/Filter.pm", $perl->project_filter());
	$tar->add_data("lib/$name/Model.pm", $perl->project_model());
	for my $item (@{$one->{component_topics}}) {
		my $c = ucfirst $item->{name_component};
		my $comp_perl = $self->_generator(
			project   => $project,
			logger    => $self->{logger},
			_config   => $self->_config(),
			component => $item,
		);
		$tar->add_data("lib/$name/$c/component.json", $item->{component_json});
		$tar->add_data("lib/$name/$c/Filter.pm", $comp_perl->filter());
		$tar->add_data("lib/$name/$c/Model.pm", $comp_perl->model());
	}
	return;
}

sub _generator {
	my ($self, %args) = @_;
	die "Unsupported language '$self->{lang}'\n" unless $self->{lang} eq 'php' || $self->{lang} eq 'perl';
	my $class = $self->{lang} eq 'perl' ? 'Tabilet::Generator::Perl' : 'Tabilet::Generator::PHP';
	return $class->new(%args);
}

sub write_tar {
	my ($self, $path) = @_;
	die "Missing tar path\n" unless $path;
	my $tar = $self->export_tar();
	$tar->write($path);
	return;
}

sub write_dir {
	my ($self, $path, $replace) = @_;
	die "Missing output path\n" unless $path;
	if (-e $path) {
		die "Output path exists. Use --replace to overwrite: $path\n" unless $replace;
		remove_tree($path);
	}
	make_path($path);

	my $tar = $self->export_tar();
	my $cwd = getcwd();
	chdir $path or die "Cannot chdir $path: $!\n";
	$tar->extract();
	chdir $cwd or die "Cannot chdir $cwd: $!\n";
	return;
}

sub summary {
	my $self = shift;
	my ($one) = $self->_load_export_data();
	return {
		projectid  => $one->{projectid},
		project    => $one->{Project},
		memberid   => $one->{memberid},
		components => scalar @{$one->{component_topics}},
		roles      => scalar @{$one->{role_topics}},
		tables     => scalar @{$one->{table_topics}},
		procedures => scalar @{$one->{stored_topics}},
	};
}

sub _from_form {
	my ($self, $form) = @_;
	return ($form->{LISTS}->[0], $form->{OTHER});
}

sub _load_export_data {
	my $self = shift;
	my $dbh = $self->_dbh();
	my $one = $self->_load_project($dbh);
	my $projectid = $one->{projectid};

	$one->{role_topics} = $self->_selectall(
		'SELECT * FROM user_role WHERE projectid=? ORDER BY roleid',
		$projectid,
	);
	$one->{component_topics} = $self->_selectall(
		'SELECT * FROM user_component WHERE projectid=? ORDER BY componentid',
		$projectid,
	);
	$one->{table_topics} = $self->_selectall(
		'SELECT * FROM user_table WHERE projectid=? ORDER BY tableid',
		$projectid,
	);
	$one->{stored_topics} = $self->_selectall(
		'SELECT * FROM user_procedure WHERE projectid=? ORDER BY procedureid',
		$projectid,
	);
	$one->{role_pub_acl} = $self->_selectall(
		'SELECT crud, a.componentid, name_component, current_key, insert_pars, edit_pars, update_pars, topics_pars FROM user_component c INNER JOIN user_action_public a USING (componentid) WHERE c.projectid=?',
		$projectid,
	);
	$one->{role_role_acl} = $self->_selectall(
		'SELECT crud, inkey, inmd5, outkey, outmd5, a.componentid, a.roleid, r.name_role, r.field_id, name_component, current_key, insert_pars, edit_pars, update_pars, topics_pars FROM user_component c INNER JOIN user_action a USING (componentid) INNER JOIN user_role r USING (roleid) WHERE c.projectid=?',
		$projectid,
	);

	my $other = {
		p_list => $self->_selectall(
			"SELECT c.name_component, IF(FIND_IN_SET('topics', p.crud)>0, 'topics', IF(FIND_IN_SET('startnew', p.crud)>0, 'startnew', '')) AS action FROM user_component c INNER JOIN user_action_public p USING (componentid) WHERE c.projectid=?",
			$projectid,
		),
		a_list => $self->_selectall(
			'SELECT name_component FROM user_component WHERE projectid=? ORDER BY componentid',
			$projectid,
		),
		r_list => $self->_selectall(
			"SELECT r.roleid, r.name_role, r.default_component, r.default_action, c.name_component, IF(t.tableid=c.tableid, 1, IF(a.inkey=t.current_key, 2, 3)) AS level, IF(t.tableid=c.tableid AND FIND_IN_SET('edit', a.crud)>0, 'edit', IF(FIND_IN_SET('topics', a.crud)>0, 'topics', 'startnew')) AS action, IF(t.tableid=c.tableid AND FIND_IN_SET('edit', a.crud)>0, 1, 0) AS is_edit, IF(FIND_IN_SET('topics', a.crud)>0, 1, 0) AS is_topics, IF(FIND_IN_SET('startnew', a.crud)>0, 1, 0) AS is_startnew FROM user_role r INNER JOIN user_table t ON (r.tableid=t.tableid) INNER JOIN user_action a USING (roleid) INNER JOIN user_component c USING (componentid) WHERE r.projectid=? AND r.name_role!='a' AND ((t.tableid=c.tableid AND (FIND_IN_SET('topics', a.crud)>0 OR FIND_IN_SET('startnew', a.crud)>0 OR FIND_IN_SET('edit', a.crud)>0)) OR (a.inkey=t.current_key AND (FIND_IN_SET('topics', a.crud)>0 OR FIND_IN_SET('startnew', a.crud)>0)) OR ((a.inkey IS NULL OR a.inkey='') AND FIND_IN_SET('topics', a.crud)>0)) ORDER BY c.componentid, level",
			$projectid,
		),
	};

	return ($one, $other);
}

sub _load_project {
	my ($self, $dbh) = @_;
	my ($sql, @bind);
	if ($self->{projectid}) {
		$sql = 'SELECT p.*, d.dbtype, d.dbname, d.dbuser, d.dbpass, d.host, d.port FROM user_project p INNER JOIN user_ds d USING (projectid) WHERE p.projectid=?';
		@bind = ($self->{projectid});
	} elsif ($self->{owner}) {
		$sql = 'SELECT p.*, d.dbtype, d.dbname, d.dbuser, d.dbpass, d.host, d.port FROM user_project p INNER JOIN user_ds d USING (projectid) INNER JOIN member m USING (memberid) WHERE m.login=?';
		@bind = ($self->{owner});
		if ($self->{project}) {
			$sql .= ' AND p.Project=?';
			push @bind, $self->{project};
		}
	} elsif ($self->{project}) {
		$sql = 'SELECT p.*, d.dbtype, d.dbname, d.dbuser, d.dbpass, d.host, d.port FROM user_project p INNER JOIN user_ds d USING (projectid) WHERE p.Project=?';
		@bind = ($self->{project});
	} else {
		die "Provide --project-id, --owner, or --project\n";
	}

	my $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind);
	die "No matching project found\n" unless @$rows;
	die "Multiple matching projects found. Add --owner or --project-id.\n" if @$rows > 1;
	return $rows->[0];
}

sub _selectall {
	my ($self, $sql, @bind) = @_;
	return $self->_dbh()->selectall_arrayref($sql, { Slice => {} }, @bind);
}

sub _dbh {
	my $self = shift;
	return $self->{dbh} if $self->{dbh};
	$self->{dbh} = $self->_connect($self->_config());
	return $self->{dbh};
}

sub _config {
	my $self = shift;
	return $self->{config} if $self->{config};
	die "Missing config_path\n" unless $self->{config_path};
	$self->{config} = $self->_read_json($self->{config_path});
	return $self->{config};
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

sub _read_json {
	my ($self, $path) = @_;
	open my $fh, '<', $path or die "Cannot open $path: $!\n";
	local $/;
	my $json = <$fh>;
	close $fh or die "Cannot close $path: $!\n";
	return decode_json($json);
}

sub _read_asset {
	my ($self, $relative) = @_;
	my $path = File::Spec->catfile($self->{asset_root}, split m{/}, $relative);
	open my $fh, '<', $path or die "Cannot open $path: $!\n";
	local $/;
	my $content = <$fh>;
	close $fh or die "Cannot close $path: $!\n";
	return $content;
}

sub _error_message {
	my ($self, $err) = @_;
	return ref($err) eq 'ARRAY' ? join(' ', @$err) . "\n" : "$err\n";
}

1;
