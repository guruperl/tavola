package Tabilet::Component::Filter;

use strict;
use DBI;
use Tabilet::Generator::PHP;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub fks {
	my $self = shift;
	return $self->SUPER::fks(@_) if @_;

	my $ARGS = $self->{ARGS};
	return {member=>["memberid",undef,"componentid","componentmd5"]}
        if ($ARGS->{g_action} eq 'topics');

    return $self->SUPER::fks();
}

sub preset {
	my $self = shift;
	my $err  = $self->SUPER::preset(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};
	my $memberid = $ARGS->{memberid};

	my $ref = {};
	my $roles = {};
	if ($who eq 'member' and ($action eq 'insert' || $action eq 'update')) {
		for my $key (keys %$ARGS) {
			if ($key =~ /^(md5)_(\d+)$/) {
				my $roleid = $2;
				if ($self->check_sign($ARGS->{$key}, $memberid, $roleid)) {
					$ref->{$roleid} = 1
				}
			} elsif ($key =~ /^(crud|inkey|inmd5|outkey|outmd5)_(\d+)$/) {
				my $column = $1;
				my $roleid = $2;
				my $value = $ARGS->{$key};
				if ($column eq 'crud' and ref($value) eq 'ARRAY') {
					$roles->{$roleid}->{$column} = join(",", @$value)
				} else {
					$roles->{$roleid}->{$column} = $value;
				}
			}
		}
		if ($ARGS->{public} && ref($ARGS->{public}) eq 'ARRAY') {
			$ARGS->{public} = join(",", @{$ARGS->{public}});
		}
		$ARGS->{roles} = {};
		for my $roleid (keys %$roles) {
			if ($ref->{$roleid}) {
				$ARGS->{roles}->{$roleid} = $roles->{$roleid};
			}
		}
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

	if ($action eq 'topics') {
		$onceextras->[0] = {projectid=>$ARGS->{projectid}, "r.is_admin"=>0};
		$onceextras->[1] = {projectid=>$ARGS->{projectid}};
	} elsif ($action eq 'insert' && $ARGS->{roles}) {
		for my $roleid (keys %{$ARGS->{roles}}) {
			my $item = $ARGS->{roles}->{$roleid};
			return 3210 if (!$item->{inkey} && $item->{inmd5});
			if (defined($item->{inkey})) {
				$err = $form->exists_column($item->{inkey}) and return $err;
				return 3211 unless $ARGS->{one};
			}
			if (defined($item->{inmd5})) {
				$err = $form->exists_column($item->{inmd5}) and return $err;
				return 3212 if $ARGS->{one};
			}
			return 3213 if ((!$item->{outkey} && $item->{outmd5}) || ($item->{outkey} && !$item->{outmd5}));
			if (defined($item->{outkey})) {
				$err = $form->exists_column($item->{outkey}) and return $err;
				return 3214 unless $ARGS->{one};
				$err = $form->exists_column($item->{outmd5}) and return $err;
				return 3215 if $ARGS->{one};
			}
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

	if ($who eq 'member' and (grep {$action eq $_} qw(insert update delete))) {
		$err = $form->set_project_def() || $form->set_role_defaults();
		return $err if $err;
	}

	if ($who eq 'member' and ($action eq 'insert' || $action eq 'update')) {
		$err = $form->call_once({model=>"component", action=>"edit"}, {componentid=>$ARGS->{componentid}}) || $form->pub_crud();
		return $err if $err;
		my $component = $form->{OTHER}->{component_edit}->[0];
		$component->{table_name} ||= $ARGS->{table_name};
		push(@{$component->{role_acl}}, {name_role=>$ARGS->{Pubrole}, crud=>$ARGS->{crud}}) if $ARGS->{crud};
		my $php = Tabilet::Generator::PHP->new(
			project => {Project=>(ucfirst $ARGS->{login})},
			logger=>$self->{LOGGER},
			component => $component);
		my $json   = $php->get_component();
		my $filter = $php->filter();
		my $model  = $php->model();
		$err = $form->update_cfm($json, $filter, $model, $ARGS->{componentid});
		return $err if $err;
	} elsif ($who eq 'member' and $action eq 'topics') {
		for my $item (@{$form->{OTHER}->{role_topics}}) {
			$item->{rolemd5} = $self->sign($ARGS->{memberid}, $item->{roleid});
		}
	} elsif ($who eq 'member' and $action eq 'edit') {
		if ($ARGS->{crud}) {
			$ARGS->{"crud_".$_} = 1 for (split(',', $ARGS->{crud}));
		}
		my $acl = $lists->[0]->{role_acl};
		if ($acl) {
			for my $item (@$acl) {
				$item->{rolemd5} = $self->sign($ARGS->{memberid}, $item->{roleid});
				$item->{$_} = 1 for (split(',', $item->{crud}));
			}
		}
	}

	return;
}

1;
