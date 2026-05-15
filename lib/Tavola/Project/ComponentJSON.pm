package Tavola::Project::ComponentJSON;

use strict;
use warnings;

use JSON qw(decode_json);

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
		my $text = $self->{files}->read_text($component->{componentJsonFile});
		$self->_validate_override_text($text, $component, "componentJsonFile $component->{componentJsonFile}");
		return $text;
	}
	if ($component->{componentJson}) {
		if (ref($component->{componentJson})) {
			$self->_validate_hash($component->{componentJson}, $component, 'componentJson');
			return $self->_json->encode($component->{componentJson});
		}
		$self->_validate_override_text($component->{componentJson}, $component, 'componentJson');
		return $component->{componentJson};
	}

	my $json = $self->hash($component, $table);
	$self->_validate_hash($json, $component, 'generated component JSON');
	return $self->_json->encode($json);
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

sub _validate_override_text {
	my ($self, $text, $component, $label) = @_;
	my $json = eval { decode_json($text) };
	die "Invalid component JSON override for $component->{name} ($label): $@\n" if $@;
	$self->_validate_hash($json, $component, $label);
	return;
}

sub _validate_hash {
	my ($self, $json, $component, $label) = @_;
	my @errors;
	my $name = $component->{name} || '(unknown)';

	if (ref($json) ne 'HASH') {
		@errors = ('must be a JSON object');
	} else {
		_require_object($json, 'actions', \@errors);
		_require_string($json, 'current_table', \@errors);
		_require_string($json, 'current_key', \@errors);
		_require_array($json, $_, \@errors) for qw(edit_pars insert_pars update_pars topics_pars);
		_validate_actions($json->{actions}, \@errors) if ref($json->{actions}) eq 'HASH';
	}

	die "Invalid component JSON for $name ($label): " . join('; ', @errors) . "\n" if @errors;
	return;
}

sub _validate_actions {
	my ($actions, $errors) = @_;
	for my $name (sort keys %$actions) {
		my $action = $actions->{$name};
		if (ref($action) ne 'HASH') {
			push @$errors, "actions.$name must be an object";
			next;
		}
		for my $key (qw(groups options)) {
			next unless exists $action->{$key};
			if (ref($action->{$key}) ne 'ARRAY') {
				push @$errors, "actions.$name.$key must be an array";
				next;
			}
			for my $i (0 .. $#{$action->{$key}}) {
				push @$errors, "actions.$name.$key\[$i\] must be a string"
					if ref($action->{$key}->[$i]);
			}
		}
	}
	return;
}

sub _require_object {
	my ($json, $key, $errors) = @_;
	if (!exists $json->{$key}) {
		push @$errors, "$key is required";
	} elsif (ref($json->{$key}) ne 'HASH') {
		push @$errors, "$key must be an object";
	}
	return;
}

sub _require_string {
	my ($json, $key, $errors) = @_;
	if (!exists $json->{$key}) {
		push @$errors, "$key is required";
	} elsif (!defined($json->{$key}) || ref($json->{$key})) {
		push @$errors, "$key must be a string";
	}
	return;
}

sub _require_array {
	my ($json, $key, $errors) = @_;
	if (!exists $json->{$key}) {
		push @$errors, "$key is required";
		return;
	}
	if (ref($json->{$key}) ne 'ARRAY') {
		push @$errors, "$key must be an array";
		return;
	}
	for my $i (0 .. $#{$json->{$key}}) {
		push @$errors, "$key\[$i\] must be a string" if ref($json->{$key}->[$i]);
	}
	return;
}

sub _json {
	return JSON->new->canonical->pretty;
}

1;
