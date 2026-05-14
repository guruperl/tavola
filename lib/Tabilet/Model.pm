package Tabilet::Model;

use strict;
use Genelet::Model;
use Genelet::Mysql;
use Tabilet::Generator::Config;

use vars qw(@ISA);
@ISA = qw(Genelet::Model Genelet::Mysql);

__PACKAGE__->setup_accessors(
	'total_force' => 1,
);

sub get_dstype {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  return $self->get_args($ARGS,
"SELECT dbname, host, port, dbtype, dbuser, dbpass, ds, is_connected
FROM user_ds
INNER JOIN user_project USING (projectid)
WHERE user_project.projectid=?", $ARGS->{projectid});
}

sub insert_creation {
  my $self = shift;
  my $ref = shift;
  my $ARGS = $self->{ARGS};

  # insert the _ip table will reset ARGS->{tableid} !! so to save it to $id
  my $id = $ARGS->{tableid} unless $ARGS->{is_auto};
  my $err;
  if ($ref->{tb}) {
    for my $item (@{$ref->{tb}}) {
      $err = $self->call_once({model=>"table", action=>"insert"}, $item) and return $err;
      $id = $self->{OTHER}->{table_insert}->[0]->{tableid} if ($item->{is_login}==1 && $ARGS->{is_auto});
    }
  }
  $ARGS->{tableid} = $id;

  if ($ref->{sp}) {
    for my $item (@{$ref->{sp}}) {
      $err = $self->call_once({model=>"stored", action=>"insert"}, $item) and return $err;
    }
  }

  return;
}

sub make_config {
	my $self = shift;
	my $extra = shift;
	my $ARGS = $self->{ARGS};

	my $hash = {};
	my $err = $self->get_args($hash,
"SELECT Project, Document_root, Server_url, Script, Pubrole, Template, Uploaddir, Log_file, dbtype, dbname, d.dbpass, d.dbuser, d.host, d.port
FROM user_project p
INNER JOIN user_ds d USING (projectid)
WHERE p.projectid = ?", $ARGS->{projectid}) || $self->call_once(
{model=>"role",action=>"topics"}, {projectid=>$ARGS->{projectid}});
	return $err if $err;

	my $config_json = Tabilet::Generator::Config->new(
		_config=>$self->{STORAGE}->{_CONFIG},
		project=>$hash,
		roles  =>$self->{OTHER}->{role_topics})->get_config();
	return $self->do_sql(
"UPDATE user_project SET config_json=?
WHERE projectid=?", $config_json, $ARGS->{projectid});
}

1;
