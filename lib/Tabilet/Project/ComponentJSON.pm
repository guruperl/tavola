package Tabilet::Project::ComponentJSON;

use strict;
use warnings;

use JSON;

sub new {
	my ($class, %args) = @_;
	return bless {
		spec => $args{spec},
		files => $args{files},
	}, $class;
}

sub encode {
	my ($self, $component, $table) = @_;

	if ($component->{componentJsonFile}) {
		return $self->{files}->read_text($component->{componentJsonFile});
	}
	if ($component->{componentJson}) {
		return ref($component->{componentJson})
			? $self->_json->encode($component->{componentJson})
			: $component->{componentJson};
	}

	return $self->_json->encode($self->hash($component, $table));
}

sub hash {
	my ($self, $component, $table) = @_;

	my $actions = {};
	for my $action (qw(startnew insert edit update delete topics)) {
		$actions->{$action} = {};
	}

	if (my $public = $component->{public}) {
		$actions->{$_} = { groups => [ $self->{spec}->{project}->{publicRole} ] } for @$public;
	}

	for my $role (sort keys %{$component->{roles} || {}}) {
		my $cruds = ref($component->{roles}->{$role}) eq 'HASH'
			? $component->{roles}->{$role}->{crud}
			: $component->{roles}->{$role};
		my @cruds = ref($cruds) eq 'ARRAY' ? @$cruds : split /\s*,\s*/, ($cruds || '');
		for my $crud (@cruds) {
			next unless exists $actions->{$crud};
			push @{$actions->{$crud}->{groups}}, $role;
		}
	}

	$actions->{startnew}->{options} = [ 'no_db', 'no_method' ] if $actions->{startnew}->{groups};

	my $json = {
		actions => $actions,
		current_table => $component->{table},
		current_key => $component->{primaryKey} || $table->{current_key},
		edit_pars => $component->{edit} || $table->{edit_pars},
		insert_pars => $component->{insert} || $table->{insert_pars},
		update_pars => $component->{update} || $table->{update_pars},
		topics_pars => $component->{topics} || $table->{topics_pars},
	};
	$json->{current_id_auto} = exists $component->{autoKey} ? $component->{autoKey} : $table->{current_id_auto}
		if exists $component->{autoKey} || $table->{current_id_auto};

	return $json;
}

sub _json {
	return JSON->new->canonical->pretty;
}

1;
