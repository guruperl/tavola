package Tabilet::Generator::Config;

use strict;
use JSON qw(decode_json);
use Genelet::Accessor;
use Genelet::Utils;
use vars qw(@ISA);
@ISA = qw(Genelet::Accessor);

__PACKAGE__->setup_accessors(
	project   => undef, # simple project object
	component => undef, # component object
	roles     => undef, # multiple role objects in array
	_config   => undef,
	logger    => undef,
);

sub get_config {
	my $self = shift;
	return $self->_json->encode($self->config_hash());
}

sub config_hash {
	my $self = shift;
	my $PROJECT = $self->{PROJECT};
	my $login = lcfirst($PROJECT->{Project});

	my $config = {};
	for my $item (qw(Document_root Project Server_url Script Pubrole Template Uploaddir)) {
		$config->{$item} = $PROJECT->{$item};
	}
	$config->{Secret} = Genelet::Utils::randomhex(100);
	$config->{Db} = [ $self->_pdo_dsn($PROJECT), $PROJECT->{dbuser} || '', $PROJECT->{dbpass} || '' ];
	$config->{Log} = {
		Filename => $PROJECT->{Log_file},
		Level => 'info',
	};
	$config->{Chartags} = {
		html => { Content_type => "text/html; charset='UTF-8'" },
		json => {
			Content_type => "application/json; charset='UTF-8'",
			Case => 1,
		},
	};
	$config->{Roles} = {};
	for my $item (@{$self->{ROLES} || []}) {
		$config->{Roles}->{$item->{name_role}} = $self->_role_hash($login, $item);
	}

	return $config;
}

sub _db_family {
	my ($self, $type) = @_;
	my $normalized = lc($type || 'mysql');
	$normalized =~ s/[^a-z0-9]//g;
	return 'mysql' if $normalized eq 'mysql' || $normalized eq 'mariadb';
	return 'postgresql' if $normalized eq 'postgresql' || $normalized eq 'postgres' || $normalized eq 'pgsql';
	return 'sqlite' if $normalized eq 'sqlite' || $normalized eq 'sqlite3';
	die "Unsupported datasource type '$type'. Use MySQL, PostgreSQL, or SQLite.\n";
}

sub _pdo_dsn {
	my ($self, $project) = @_;
	my $family = $self->_db_family($project->{dbtype});
	my $dbname = $project->{dbname} || $project->{database} || '';

	return 'sqlite:' . $dbname if $family eq 'sqlite';

	my $driver = $family eq 'postgresql' ? 'pgsql' : 'mysql';
	my @parts;
	push @parts, 'host=' . $project->{host} if defined($project->{host}) && length($project->{host});
	push @parts, 'port=' . $project->{port} if defined($project->{port}) && length($project->{port});
	push @parts, 'dbname=' . $dbname;
	return $driver . ':' . join(';', @parts);
}

sub perl_db_adapter {
	my $self = shift;
	my $family = $self->_db_family($self->{PROJECT}->{dbtype});
	return 'Mysql' if $family eq 'mysql';
	return 'Pg' if $family eq 'postgresql';
	return 'SQLite' if $family eq 'sqlite';
	die "Unsupported datasource type '$self->{PROJECT}->{dbtype}'\n";
}

sub _facebook_hash {
	my ($self, $name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) = @_;
	return {
		Default => JSON::true,
		Screen => 0,
		Provider_pars => {
			scope => 'public_profile,email',
			callback_url => "http://$domain/app.php/$name_role/html/facebook",
			client_id => 'CLIENT_ID',
			client_secret => 'CLIENT_SECRET',
		},
		Credential => [ 'code' ],
		Sql => $proc_name,
		In_pars => [ 'email', 'first_name', 'last_name', 'access_token', 'expires_in', 'id' ],
		Out_pars => [ $field_id, $field_login, $name_role . '_' . $field_firstname, $name_role . '_' . $field_lastname ],
	};
}

sub _google_hash {
	my ($self, $name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) = @_;
	return {
		Default => JSON::true,
		Screen => 0,
		Provider_pars => {
			scope => 'profile email',
			callback_url => "http://$domain/app.php/$name_role/html/google",
			client_id => 'CLIENT_ID',
			client_secret => 'CLIENT_SECRET',
		},
		Credential => [ 'code' ],
		Sql => $proc_name,
		In_pars => [ 'email', 'given_name', 'family_name', 'access_token', 'expires_in', 'id', 'id_token', 'refresh_token', 'picture' ],
		Out_pars => [ $field_id, $field_login, $name_role . '_' . $field_firstname, $name_role . '_' . $field_lastname ],
	};
}

sub _zoom_hash {
	my ($self, $name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) = @_;
	return {
		Default => JSON::true,
		Screen => 0,
		Provider_pars => {
			scope => 'meeting:read:admin meeting:write:admin',
			callback_url => "http://$domain/app.php/$name_role/html/zoom",
			client_id => 'CLIENT_ID',
			client_secret => 'CLIENT_SECRET',
		},
		Credential => [ 'code' ],
		Sql => $proc_name,
		In_pars => [ 'email', 'first_name', 'last_name', 'access_token', 'expires_in', 'id', 'refresh_token', 'pic_url' ],
		Out_pars => [ $field_id, $field_login, $name_role . '_' . $field_firstname, $name_role . '_' . $field_lastname ],
	};
}

sub _issuer_hash {
	my ($self, $name_role, $proc_name, $field_id, $field_login, $field_passwd, $field_firstname, $field_lastname) = @_;
	return {
		Default => JSON::true,
		Screen => 1,
		Credential => [ $field_login, $field_passwd, 'direct', "t$name_role" ],
		Sql => $proc_name,
		In_pars => [ $field_login, $field_passwd ],
		Out_pars => [ $field_id, $field_login, $name_role . '_' . $field_firstname, $name_role . '_' . $field_lastname ],
	};
}

sub _role_hash {
	my $self = shift;
	my $login = shift;
	my $item = shift;

	my $name_role = $item->{name_role};
	my $proc_name = $item->{procedure_name} || $item->{proc_name};
	my $is_admin = $item->{is_admin};
	my $type_id = $item->{roleid};
	my $authen = $item->{authen};
	my $field_id = $item->{field_id};
	my $field_login = $item->{field_login};
	my $field_passwd = $item->{field_passwd};
	my $field_firstname = $item->{field_firstname};
	my $field_lastname = $item->{field_lastname};
	my $domain = $login . "." . $self->{_CONFIG}->{Custom}->{USER_domain};

	my $issuer = ($authen eq 'google') ?
		$self->_google_hash($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) : ($authen eq 'zoom') ?
		$self->_zoom_hash($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) : ($authen eq 'facebook') ?
		$self->_facebook_hash($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) :
		$self->_issuer_hash($name_role, $proc_name, $field_id, $field_login, $field_passwd, $field_firstname, $field_lastname);

	my $role = {
		Id_name => $field_id,
		Attributes => [ $field_id, $field_login, $name_role . '_' . $field_firstname, $name_role . '_' . $field_lastname ],
		Type_id => $type_id,
		Surface => "t$name_role",
		Domain => $domain,
		Duration => 86400,
		Max_age => 86400,
		Secret => Genelet::Utils::randomhex(100),
		Coding => Genelet::Utils::randomhex(100),
		Logout => '/',
		Issuers => {
			$authen => $issuer,
		},
	};
	$role->{Is_admin} = JSON::true if $is_admin;

	return $role;
}

sub get_component {
	my $self  = shift;
	my $COMP = $self->{COMPONENT};
	return $self->_json->encode($self->component_hash($COMP));
}

sub component_hash {
	my ($self, $COMP) = @_;

	my $acts = {};
	my $fks;
	my $ref;
	for my $item (@{$COMP->{role_acl}}) {
		my @roles = split(',', $item->{crud});
		push(@{$acts->{$_}}, $item->{name_role}) for @roles;
		$ref->{$item->{name_role}} = 1;
		if ($item->{inkey} || $item->{inmd5} || $item->{outkey} || $item->{outmd5}) {
			$fks->{$item->{name_role}} = [
				$item->{inkey}  || JSON::false,
				$item->{inmd5}  || JSON::false,
				$item->{outkey} || JSON::false,
				$item->{outmd5} || JSON::false,
			];
		}
	}

	my $actions = {};
	if ($ref) {
		$actions->{startnew} = { groups => [ keys %$ref ], options => [ 'no_db', 'no_method' ] };
	}
	for my $act (qw(insert edit update delete topics)) {
		my $names = $acts->{$act};
		if ($names) {
			$actions->{$act} = { groups => $names };
		} else {
			$actions->{$act} = {};
		}
	}

	my $json = {
		actions => $actions,
		current_table => $COMP->{table_name},
		current_key => $COMP->{current_key},
		edit_pars => decode_json($COMP->{edit_pars} || '[]'),
		insert_pars => decode_json($COMP->{insert_pars} || '[]'),
		update_pars => decode_json($COMP->{update_pars} || '[]'),
		topics_pars => decode_json($COMP->{topics_pars} || '[]'),
	};
	$json->{fks} = $fks if $fks;
	$json->{current_id_auto} = $COMP->{current_id_auto} if $COMP->{current_id_auto};
	$json->{current_tables} = decode_json($COMP->{current_tables}) if $COMP->{current_tables};

	return $json;
}

sub _json {
	return JSON->new->canonical->pretty;
}

1;
