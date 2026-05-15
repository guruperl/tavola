package Tabilet::Project::JSONSchema;

use strict;
use warnings;

use JSON ();
use Scalar::Util qw(looks_like_number);

sub new {
	my ($class, %args) = @_;
	return bless {
		schema => $args{schema},
	}, $class;
}

sub validate {
	my ($self, $data) = @_;
	my @errors;
	$self->_validate($self->{schema}, $data, '$', \@errors);
	return @errors;
}

sub _validate {
	my ($self, $schema, $data, $path, $errors) = @_;
	return unless ref($schema) eq 'HASH';

	if (exists $schema->{const} && !_same($data, $schema->{const})) {
		push @$errors, "$path must equal " . _describe($schema->{const});
		return;
	}

	if (exists $schema->{enum}) {
		my $ok = 0;
		for my $allowed (@{$schema->{enum}}) {
			if (_same($data, $allowed)) {
				$ok = 1;
				last;
			}
		}
		push @$errors, "$path must be one of " . join(', ', map { _describe($_) } @{$schema->{enum}}) unless $ok;
		return unless $ok;
	}

	if (exists $schema->{type} && !$self->_matches_type($data, $schema->{type})) {
		push @$errors, "$path must be " . _type_label($schema->{type});
		return;
	}

	if (($schema->{type} || '') eq 'object' || ref($schema->{properties}) eq 'HASH') {
		return unless ref($data) eq 'HASH';
		my $properties = $schema->{properties} || {};
		for my $key (@{$schema->{required} || []}) {
			push @$errors, "$path.$key is required" unless exists $data->{$key};
		}
		if (exists $schema->{additionalProperties} && !$schema->{additionalProperties}) {
			my %allowed = map { $_ => 1 } keys %$properties;
			for my $key (sort keys %$data) {
				push @$errors, "$path.$key is not allowed" unless $allowed{$key};
			}
		}
		for my $key (sort keys %$properties) {
			next unless exists $data->{$key};
			$self->_validate($properties->{$key}, $data->{$key}, "$path.$key", $errors);
		}
	}

	if (($schema->{type} || '') eq 'array' || ref($schema->{items}) eq 'HASH') {
		return unless ref($data) eq 'ARRAY';
		if (exists $schema->{minItems} && @$data < $schema->{minItems}) {
			push @$errors, "$path must contain at least $schema->{minItems} item(s)";
		}
		if (my $items = $schema->{items}) {
			for my $i (0 .. $#$data) {
				$self->_validate($items, $data->[$i], "$path\[$i\]", $errors);
			}
		}
	}

	return;
}

sub _matches_type {
	my ($self, $data, $type) = @_;
	if (ref($type) eq 'ARRAY') {
		for my $candidate (@$type) {
			return 1 if $self->_matches_type($data, $candidate);
		}
		return 0;
	}
	return !defined($data) if $type eq 'null';
	return ref($data) eq 'HASH' if $type eq 'object';
	return ref($data) eq 'ARRAY' if $type eq 'array';
	return JSON::is_bool($data) if $type eq 'boolean';
	return defined($data) && !ref($data) && !JSON::is_bool($data) if $type eq 'string';
	return defined($data) && !ref($data) && looks_like_number($data) && int($data) == $data if $type eq 'integer';
	return defined($data) && !ref($data) && looks_like_number($data) if $type eq 'number';
	return 0;
}

sub _same {
	my ($left, $right) = @_;
	return 1 if !defined($left) && !defined($right);
	return 0 if !defined($left) || !defined($right);
	return 1 if JSON::is_bool($left) && JSON::is_bool($right) && (($left ? 1 : 0) == ($right ? 1 : 0));
	return 0 if JSON::is_bool($left) || JSON::is_bool($right);
	if (ref($left) eq 'ARRAY' && ref($right) eq 'ARRAY') {
		return 0 unless @$left == @$right;
		for my $i (0 .. $#$left) {
			return 0 unless _same($left->[$i], $right->[$i]);
		}
		return 1;
	}
	if (ref($left) eq 'HASH' && ref($right) eq 'HASH') {
		return 0 unless keys(%$left) == keys(%$right);
		for my $key (keys %$left) {
			return 0 unless exists $right->{$key} && _same($left->{$key}, $right->{$key});
		}
		return 1;
	}
	return 0 if ref($left) || ref($right);
	return "$left" eq "$right";
}

sub _type_label {
	my $type = shift;
	return join(' or ', @$type) if ref($type) eq 'ARRAY';
	return $type;
}

sub _describe {
	my $value = shift;
	return 'null' unless defined $value;
	return $value ? 'true' : 'false' if JSON::is_bool($value);
	return JSON->new->canonical->encode($value) if ref($value);
	return "'$value'";
}

1;
