package Tabilet::Generator::Config;

use strict;
use Genelet::Accessor;
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

	my $PROJECT = $self->{PROJECT};

	my $login = lcfirst($PROJECT->{Project});

	my $role = "";
	for my $item (@{$self->{ROLES}}) {
		$role .= qq~\n\t\t"~.$item->{name_role}.'" : '.$self->_get_role($login, $item).","
    }
	substr($role,-1,1) = "";

	my $json  = "{\n";
	foreach my $item (qw(Document_root Project Server_url Script Pubrole Template Uploaddir)) {
		$json .= qq~\t"$item" : "~.$PROJECT->{$item}.qq~",\n~;
	}
	$json .= qq~\t"Secret" : "~.Genelet::Utils::randomhex(100).qq~",
	"Db" : ["~.lc($PROJECT->{dbtype}).qq~:host=~.$PROJECT->{host}.qq~;dbname=$PROJECT->{dbname}", "~.$PROJECT->{dbuser}.qq~", "~.$PROJECT->{dbpass}.qq~"],
	"Log" : {"Filename": "~.$PROJECT->{Log_file}.qq~", "Level": "info"},
	"Chartags" : {
		"html":{"Content_type":"text/html; charset='UTF-8'"},
		"json" : {
			"Content_type":"application/json; charset='UTF-8'",
			"Case":1
		}
	},
	"Roles" : {$role
	}
}~;
	return $json;
}

sub _get_facebook {
  my $self = shift;
  my ($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname)  = @_;
  return qq~{
					"Default" : true,
					"Screen"  : 0,
					"Provider_pars": {
						"scope": "public_profile,email",
						"callback_url":"http://$domain/app.php/$name_role/html/facebook",
						"client_id": "CLIENT_ID",
						"client_secret": "CLIENT_SECRET"
					},
					"Credential" : ["code"],
					"Sql": "$proc_name",
					"In_pars": ["email", "first_name", "last_name", "access_token", "expires_in", "id"],
					"Out_pars": ["$field_id", "$field_login", "$name_role~.qq~_$field_firstname", "$name_role~.qq~_$field_lastname"]
				}~;
}

sub _get_google {
  my $self = shift;
  my ($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname)  = @_;
  return qq~{
					"Default" : true,
					"Screen"  : 0,
					"Provider_pars": {
						"scope": "profile email",
						"callback_url":"http://$domain/app.php/$name_role/html/google",
						"client_id": "CLIENT_ID",
						"client_secret": "CLIENT_SECRET"
					},
					"Credential" : ["code"],
					"Sql": "$proc_name",
					"In_pars": ["email", "given_name", "family_name", "access_token", "expires_in", "id", "id_token", "refresh_token", "picture"],
					"Out_pars": ["$field_id", "$field_login", "$name_role~.qq~_$field_firstname", "$name_role~.qq~_$field_lastname"]
				}~;
}

sub _get_zoom {
  my $self = shift;
  my ($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname)  = @_;
  return qq~{
					"Default" : true,
					"Screen"  : 0,
					"Provider_pars": {
						"scope": "meeting:read:admin meeting:write:admin",
						"callback_url":"http://$domain/app.php/$name_role/html/zoom",
						"client_id": "CLIENT_ID",
						"client_secret": "CLIENT_SECRET"
					},
					"Credential" : ["code"],
					"Sql": "$proc_name",
					"In_pars": ["email", "first_name", "last_name", "access_token", "expires_in", "id", "refresh_token", "pic_url"],
					"Out_pars": ["$field_id", "$field_login", "$name_role~.qq~_$field_firstname", "$name_role~.qq~_$field_lastname"]
				}~;
}

sub _get_issuer {
  my $self = shift;
  my ($name_role, $proc_name, $field_id, $field_login, $field_passwd, $field_firstname, $field_lastname)  = @_;
  return qq~{
					"Default" : true,
					"Screen"  : 1,
					"Credential" : ["$field_login", "$field_passwd", "direct", "t$name_role"],
					"Sql": "$proc_name",
					"In_pars" : ["$field_login", "$field_passwd"],
					"Out_pars": ["$field_id", "$field_login", "$name_role~.qq~_$field_firstname", "$name_role~.qq~_$field_lastname"]
				}~;
}

sub _get_role {
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

  my $domain = $login.".".$self->{_CONFIG}->{Custom}->{USER_domain};

  my $issuer = ($authen eq 'google') ?
$self->_get_google($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) : ($authen eq 'zoom') ?
$self->_get_zoom($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) : ($authen eq 'facebook') ?
$self->_get_facebook($name_role, $proc_name, $field_id, $field_login, $domain, $field_firstname, $field_lastname) :
$self->_get_issuer($name_role, $proc_name, $field_id, $field_login, $field_passwd, $field_firstname, $field_lastname);

  my $str = "";
  $str = qq~\n\t\t\t"Is_admin" : true,~ if $is_admin;
  return qq~{$str
			"Id_name" : "$field_id",
			"Attributes" : ["$field_id", "$field_login", "$name_role~.qq~_$field_firstname", "$name_role~.qq~_$field_lastname"],
			"Type_id" : $type_id,
			"Surface" : "t$name_role",
			"Domain"  : "$domain",
			"Duration": 86400,
			"Max_age" : 86400,
			"Secret"  : "~.Genelet::Utils::randomhex(100).qq~",
			"Coding"  : "~.Genelet::Utils::randomhex(100).qq~",
			"Logout"  : "/",
			"Issuers" : {
				"$authen" : $issuer
			}
		}~;
}

sub get_component {
	my $self  = shift;

	my $COMP = $self->{COMPONENT};

	my $acts = {};
	my $fks;
	my $ref;
	for my $item (@{$COMP->{role_acl}}) {
		my @roles = split(',', $item->{crud});
		push(@{$acts->{$_}}, $item->{name_role}) for @roles;
		$ref->{$item->{name_role}} = 1;
		if ($item->{inkey} || $item->{inmd5} || $item->{outkey} || $item->{outmd5}) {
			my $a1 = "false";
			my $a2 = "false";
			my $a3 = "false";
			my $a4 = "false";
			$a1 = '"'.$item->{inkey}.'"'  if $item->{inkey};
			$a2 = '"'.$item->{inmd5}.'"'  if $item->{inmd5};
			$a3 = '"'.$item->{outkey}.'"' if $item->{outkey};
			$a4 = '"'.$item->{outmd5}.'"' if $item->{outmd5};
			$fks->{$item->{name_role}} = qq~[$a1,$a2,$a3,$a4]~;
		}
	}	
	my $str = qq~{\n\t"actions" : {~;
	if ($ref) {
		$str .= qq~\n\t\t"startnew" : {"groups":["~.join('","', keys %$ref).qq~"],"options":["no_db", "no_method"]},~;
	}
	for my $act (qw(insert edit update delete topics)) {
		my $names = $acts->{$act};
		if ($names) {
			$str .= qq~\n\t\t"$act" : {"groups":["~.join('","', @$names).qq~"]},~;
		} else {
			$str .= qq~\n\t\t"$act" : {},~;
		}
	}
	substr($str,-1,1) = qq~\n\t},~;
	if ($fks) {
		$str .= qq~\n\t"fks" : {~;
		for my $name (keys %$fks) {
			$str .= qq~\n\t\t"$name" : ~.$fks->{$name}.qq~,~;
		}
		substr($str,-1,1) = qq~\n\t},~;
	}
	$str .= qq~\n\t"current_table" : "~.$COMP->{table_name}.qq~",
	"current_key" : "~.$COMP->{current_key}.qq~",~;
	if ($COMP->{current_id_auto}) {
		$str .= qq~\n\t"current_id_auto" : "~.$COMP->{current_id_auto}.qq~",~;
	}
	if ($COMP->{current_tables}) {
		$str .= qq~\n\t\t"current_tables" : ~.$COMP->{current_tables}.qq~,~;
	}
	$str .= qq~\n\t"edit_pars"   : ~.$COMP->{edit_pars}.qq~,
	"insert_pars" : ~.$COMP->{insert_pars}.qq~,
	"update_pars" : ~.$COMP->{update_pars}.qq~,
	"topics_pars" : ~.$COMP->{topics_pars};
	return $str . qq~\n}~;
}

1;
