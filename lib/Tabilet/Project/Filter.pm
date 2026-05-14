package Tabilet::Project::Filter;

use strict;
use JSON;
use Time::Piece;
use Archive::Tar;
use Cwd qw(getcwd);
use Genelet::Utils;
use Tabilet::Github;
use Tabilet::Project::Exporter;
use Tabilet::Schema;
use Tabilet::SchemaDatabase;
use Tabilet::Generator::PHP;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub init_ds {
	my $self = shift;
	my $ARGS   = $self->{ARGS};

	my $type = $ARGS->{dbtype};
	$ARGS->{nickname} = "myDB";
	$ARGS->{dbname}   = $ARGS->{login};
	$ARGS->{host}     = $self->{CUSTOM}->{$type}->{host};
	$ARGS->{port}     = $self->{CUSTOM}->{$type}->{port};
	$ARGS->{dbuser}   = $ARGS->{login};
	$ARGS->{dbpass}   = Genelet::Utils::randomhex(10);

	return;
}

sub init_role {
	my $self = shift;
	my $ARGS   = $self->{ARGS};

	$ARGS->{name_role}   = $self->{CUSTOM}->{DB_admin}->{role};
	$ARGS->{description} = "Built-in administrator";
	$ARGS->{authen}      = "db";
	$ARGS->{is_admin}    = 1;
	$ARGS->{is_auto}     = 1;
	$ARGS->{field_id}    = $ARGS->{name_role} . "_id";
	$ARGS->{field_login} = "email";
	$ARGS->{field_passwd}= "passwd";
	$ARGS->{field_firstname}= "firstname";
	$ARGS->{field_lastname}= "lastname";

	return $self->table_proc_names();
}

sub init_project {
	my $self = shift;
	my $ARGS   = $self->{ARGS};

	my $c = $self->{CUSTOM};
	my $login = $ARGS->{login};
	my $root  = $c->{USER_root} . "/" . $login;
	$ARGS->{Document_root}= $root . "/www";
	$ARGS->{Project}      = ucfirst($login);
	$ARGS->{Server_url}   = "http://" . $login . "." . $c->{USER_domain};
	$ARGS->{Script}       = "/app.php";
	$ARGS->{Pubrole}      = "p";
	$ARGS->{Template}     = $root . "/views";
	$ARGS->{Uploaddir}    = $root . "/www/upload";
	$ARGS->{Log_file}     = $root."/logs/debug.log";
	$ARGS->{admin_role}   = $self->{CUSTOM}->{DB_admin}->{role};
	$ARGS->{admin_user}   = $self->{CUSTOM}->{DB_admin}->{user};
	$ARGS->{admin_pass}   = Genelet::Utils::randompw(8);
	return;
}

sub preset {
	my $self = shift;
	my $err  = $self->SUPER::preset(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	if ($action eq 'insert') {
		$self->init_project();
		$err = $self->init_role() and return $err;
		$ARGS->{ds} ||= "online";
		if ($ARGS->{ds} eq 'online') {
			$self->init_ds();
		}
	}

	if ($who eq 'admin' && $action eq 'loginas') {
		$err = $self->set_login_cookie_as('member', $ARGS->{login}) and return $err;
		$r->{"headers_out"}->{"Location"} = "../../member/en/project?action=topics";
		return 303;
	}

	return;
}

sub before {
	my $self = shift;
	my $err  = $self->SUPER::before(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	my ($form, $extra, $nextextras, $onceextras) = @_;

	if ($who eq 'admin' && $action eq 'topics') {
		$extra->{memberid} = $ARGS->{memberid};
	} elsif ($action eq 'delete') {
		$err = $form->get_dstype() and return $err;
		if ($ARGS->{ds} eq 'online') {
			my $schema = Tabilet::SchemaDatabase->new(args=>$ARGS, logger=>$self->{LOGGER});
			if ($ARGS->{dbtype} eq 'PostgreSQL') {
				$err = $schema->set_dbh($form, $self->{CUSTOM}, $ARGS->{login}) || $schema->drop_extension();
				$schema->{DBH}->disconnect if $schema->{DBH};
				return $err if $err;
			}
			$err = $schema->set_dbh($form, $self->{CUSTOM}) || $schema->drop_database();
			$schema->{DBH}->disconnect if $schema->{DBH};
			return $err if $err;
		} elsif ($ARGS->{is_connected} eq 'Yes') {
			$err = $form->get_tabilet_tables() and return $err;
			my $schema = Tabilet::Schema->new(args=>$ARGS, logger=>$self->{LOGGER});
			$err = $schema->set_dbh($form) || $schema->drop_tabilet_tables();
			$schema->{DBH}->disconnect if $schema->{DBH};
			return $err if $err;
		}
	}

	return;
}

sub after {
	my $self = shift;
	my $err  = $self->SUPER::after(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

    my ($form) = @_;
    my $lists = $form->{LISTS};
    my $other = $form->{OTHER};

	if ($action eq 'insert') {
		if ($ARGS->{ds} eq 'online') {
			my $schema = Tabilet::SchemaDatabase->new(args=>$ARGS, logger=>$self->{LOGGER});
			my $err = $schema->set_dbh($form, $self->{CUSTOM}) || $schema->create_database();
			$schema->{DBH}->disconnect if $schema->{DBH};
			return $err if $err;
			# extention pgcrypto is for indivisual database, 
			# so create it by root for that database !
			if ($ARGS->{dbtype} eq 'PostgreSQL') {
				$err = $schema->set_dbh($form, $self->{CUSTOM}, $ARGS->{login}) || $schema->create_extension();
				$schema->{DBH}->disconnect if $schema->{DBH};
				return $err if $err;
			}
		}
		my $ref = {};
		my $schema = Tabilet::Schema->new(args=>$ARGS, logger=>$self->{LOGGER});
		$err = $schema->set_dbh($form) || $schema->set_login_tables($ref, 'db');
		$schema->{DBH}->disconnect if $schema->{DBH};
		return $err if $err;
		$err = $form->insert_creation($ref) || $form->call_once(
{model=>"role", action=>"insert"}) || $form->do_sql(
"UPDATE user_ds SET is_connected='Yes' WHERE dsid=?", $ARGS->{dsid});
		return $err if $err;
	}

	if ($action eq 'startnew' && $ARGS->{ok}) {
        $self->set_cookie($self->{PROVIDER_NAME},  '{"typeid":'.$ARGS->{typeid}.',"in_login":"'.$ARGS->{login}.'", "memberid":'.$ARGS->{memberid}.'}');
		my $github = Tabilet::Github->new(github=> $self->{CUSTOM}->{GITHUB},
			args  => $ARGS, logger=> $self->{LOGGER});
		$err = $github->find_remote() and return $err;
		if ($ARGS->{git_login}) {
			$err = $github->find_collaborator() and return $err;
		}
	} elsif ($action eq 'xerase') {
		my $github = Tabilet::Github->new(github=> $self->{CUSTOM}->{GITHUB},
			args  => $ARGS, logger=> $self->{LOGGER});
		$err = $github->erase() and return $err;
	} elsif ($action eq 'topics') {
		#$ARGS->{total_existing} = $other->{team_topics} ? scalar(@{$other->{team_topics}}) : 1;
        # login subscription is none, check instant subscription too
		if (($ARGS->{memberid} eq $ARGS->{m_groupid}) and grep {$ARGS->{m_subscription} eq $_} (qw(NONE EXPIRED CANCELLED SUSPENDED PAYMENT.FAILED))) {
			$ARGS->{client_id} = $self->{CUSTOM}->{PAYPAL}->{client_id};
			$err = $form->get_subscription() and return $err;
		}
		$self->set_report($_) for @$lists;
	} elsif ($action eq 'insert') {
		for (qw(dbtype dbname host port dbuser dbpass)) {
			$lists->[0]->{$_} = $ARGS->{$_} unless defined($lists->[0]->{$_});
		}
		# we add procedure_name which is not in the role insert's LISTS
		$other->{role_insert}->[0]->{procedure_name} = $ARGS->{proc_name};
		my $php = Tabilet::Generator::PHP->new(
			_config=>$self->{STORAGE}->{_CONFIG},
			project=>$lists->[0],
			logger=>$self->{LOGGER},
			roles  =>$other->{role_insert});
		$err = $form->upd_config($php->get_config(), $php->project_filter(), $php->project_model()) and return $err;
	} elsif ($action eq 'set_r' and !$ARGS->{is_a}) {
		$err = $form->make_config() and return $err;
	} elsif ($action eq 'edit' and $ARGS->{_gtag} eq 'xtar') {
		my $tar = Archive::Tar->new;
		$err = $self->get_tar($tar, $form) and return $err;
		$r->{headers_out}->{"Content-Disposition"} = "attachment; filename=\"php_".$ARGS->{login}.".tar\"";
		$r->{headers_out}->{"Cache-Control"} = "must-revalidate";
		$other->{tar} = $tar->write();
	} elsif ($action eq 'xgit') {
		my $tar = Archive::Tar->new;
		$err = $self->get_tar($tar, $form);
		return $err if $err;
		my $root  = $self->{CUSTOM}->{USER_root} . "/" . $ARGS->{login};
		mkdir $root unless (-d $root);
		my $cwd = getcwd();
		chdir $root or return $!;
		$other->{tar} = $tar->extract();
		chdir $cwd or return $!;
		my $github = Tabilet::Github->new(github=> $self->{CUSTOM}->{GITHUB},
			args  => $ARGS, logger=> $self->{LOGGER});
		$err = $github->push() and return $err;
		unless ($ARGS->{is_coll}) {
			my $hash = {};
			$err = $form->get_github($hash) || $github->invite($hash);
			return $err if $err;
		}
	}

	if ($ENV{SCRIPT_NAME} eq '/cgi-bin/xtabi') {
        $r->{"headers_out"}->{"Location"} = $self->{SCRIPT}."/member/en/project?action=startnew";
        return 303;
	}

	return;
}


sub get_tar {
	my $self = shift;
	my ($tar, $form) = @_;

	my $exporter = Tabilet::Project::Exporter->new(
		config     => $self->{STORAGE}->{_CONFIG},
		asset_root => $self->{DOCUMENT_ROOT} . "/..",
		logger     => $self->{LOGGER},
	);
	return $exporter->add_to_tar($tar, $form);
}

sub set_report {
	my $self = shift;
	my $one = shift;

	my $lists_component = $one->{component_topics};
	my $lists_role = $one->{role_topics};
	#my $t = Time::Piece->strptime($one->{created}, '%F %T');
	my $t = Time::Piece->strptime($one->{created}, '%Y-%m-%d %H:%M:%S');
	$one->{created} = $t->strftime("%b %d");
	$one->{db_roles} = join(",", map {$_->{name_role}} @$lists_role);
	$one->{db_comps} = join(",", map {$_->{name_component}} @$lists_component);
	for my $item (@$lists_component) {
		# those display private infos, delete
		delete $item->{$_} for (qw(component_json filter model));
	}
	$one->{Server_url} = "http://WEBSITE";
	if ($one->{config_json}) { # to add extras like cookie to lists of roles
		my $json = decode_json $one->{config_json};
		my $ref = {};
		foreach my $role (keys %{$json->{Roles}}) {
			my $role_obj = $json->{Roles}->{$role};
			my $issuer   = $role_obj->{Issuers};
			foreach my $authen (keys %$issuer) {
				my $item = $issuer->{$authen};
				$ref->{$role} = {role=>$role, cookie=>$role_obj->{Surface}, logout=>$role_obj->{Logout}, duration=>$role_obj->{Duration}, login=>$item->{Credential}->[0], pass=>$item->{Credential}->[1], sql=>$item->{Sql}}
			}
		}
		for my $item (@$lists_role) {
			$item->{$_} = $ref->{$item->{name_role}}->{$_} for (keys %{$ref->{$item->{name_role}}});
		}
		# delete private info
		delete $one->{config_json};
	}
	if ($one->{role_pub_acl}) { # re-process crud
		for my $single (@{$one->{role_pub_acl}}) {
			$single->{cruds}->{$_} = check_crud($single, $_) for (split(',', $single->{crud},-1));
			delete $single->{crud};
		}
	}
	if ($one->{role_role_acl}) {
		my $all = {}; # to make a tree structure => role_name => component_obj
		for my $single (@{$one->{role_role_acl}}) { 
			$single->{cruds}->{$_} = check_crud($single, $_) for (split(',', $single->{crud},-1)); # re-structure crud
			delete $single->{crud};
			push @{$all->{$single->{name_role}}}, $single;
		}
		$one->{role_role_acl} = $all;
	}
	return;
}

sub clean {
	my $str = shift;
	my $extra = shift || '';
	substr($str, 0,1) = "";
	substr($str,-1,1) = "";
	my @arr = split ',', $str, -1;
	return join(",\n$extra", map {$_ . ":STRING"} @arr);
}

sub check_crud {
	my ($item, $action) = @_;
	my $method = "GET";
	my $name = "query";
	my $in;
	my $out;

	my $in_get = "";
	my $in_post = "";
	my $out4 = "";
	my $out6 = "";
	if ($item->{inkey} and $item->{inkey} ne $item->{field_id}) {
		$in_get = qq~&~.$item->{inkey}.qq~=STRING&~.$item->{inmd5}.qq~=STRING~;
		$in_post = qq~\n  "~.$item->{inkey}.qq~":STRING,
  "~.$item->{inmd5}.qq~":STRING,~;
	}
	if ($item->{outkey}) {
		$out4 = qq~\n    "~.$item->{outmd5}.qq~":STRING,~;
		$out6 = qq~\n      "~.$item->{outmd5}.qq~":STRING,~;
	}

	if ($action eq 'insert') {	
		$method = "POST";
		$name = "body";
		$in = qq~{
  "action":"insert",$in_post
  ~.clean($item->{insert_pars}, ' ').qq~
}~;
		$out= qq~{
  "success":true,
  "incomings":{
    "action":"insert",
    ~.clean($item->{insert_pars}, '   ').qq~
  },
  "data":[{
    ~.clean($item->{edit_pars}, '   ').qq~
  }]
}~;
	} elsif ($action eq 'edit') {
		$in = qq~action=edit&~.$item->{current_key}.qq~=CODE$in_get~;
		$out= qq~{
  "success":true,
  "incomings":{
    "action":"edit",
    "~.$item->{current_key}.qq~":CODE
  },
  "included":{
    "csrf":STRING
  },
  "data":[{$out4
    ~.clean($item->{edit_pars}, '   ').qq~
  }]
}~;
	} elsif ($action eq 'delete') {
		$in = qq~action=delete&~.$item->{current_key}.qq~=CODE$in_get~;
		$out= qq~{
  "success":true,
  "incomings":{
    "action":"edit",
    "~.$item->{current_key}.qq~":CODE
  }
}~;
	} elsif ($action eq 'update') {	
		$method = "POST";
		$name = "body";
		$in = qq~{
  "action":"insert",$in_post
  ~.clean($item->{update_pars}, ' ').qq~
}~;
		$out= qq~{
  "success":true,
  "incomings":{
    "action":"update",
    ~.clean($item->{update_pars}, '   ').qq~
  }
}~;
	} elsif ($action eq 'topics') {	
		$in = qq~action=topics$in_get~;
		$out= qq~{
  "success":true,
  "incomings":{
    "action":"topics"
  },
  "included":{
    "csrf":STRING
  },
  "data":[
    {$out6
      ~.clean($item->{topics_pars}, '     ').qq~
    },
    {...},
  ]
}~;
	}
	
	return [$method, $name, $in, $out];
}

1;
