package Tavola::Project::Spec;

use strict;
use warnings;

use Tavola::Project::Spec::Files;
use Tavola::Project::Spec::Importer;
use Tavola::Project::Spec::MetadataBuilder;
use Tavola::Project::Spec::Paths;
use Tavola::Project::Spec::Validator;

sub new {
	my ($class, %args) = @_;
	return bless {
		config_path => $args{config_path},
		spec_path   => $args{spec_path},
		replace     => $args{replace} ? 1 : 0,
		dry_run     => $args{dry_run} ? 1 : 0,
		config      => undef,
		spec        => undef,
		files       => undef,
	}, $class;
}

sub run {
	my $self = shift;

	$self->_load_spec();

	if ($self->{dry_run}) {
		$self->_print_plan();
		return;
	}

	die "Missing --config\n" unless $self->{config_path};
	$self->{config} = $self->_files->read_json($self->{config_path});

	Tavola::Project::Spec::Importer->new(
		spec    => $self->{spec},
		config  => $self->{config},
		files   => $self->_files,
		paths   => $self->_paths,
		replace => $self->{replace},
	)->run();

	return;
}

sub export_data {
	my $self = shift;

	$self->_load_spec();
	$self->{config} = $self->_files->read_json($self->{config_path}) if $self->{config_path};

	return Tavola::Project::Spec::MetadataBuilder->new(
		spec   => $self->{spec},
		config => $self->{config},
		files  => $self->_files,
		paths  => $self->_paths,
	)->build();
}

sub export_summary {
	my $self = shift;
	my ($one) = $self->export_data();
	return {
		project    => $one->{Project},
		memberid   => $one->{memberid},
		components => scalar @{$one->{component_topics}},
		roles      => scalar @{$one->{role_topics}},
		tables     => scalar @{$one->{table_topics}},
		procedures => scalar @{$one->{stored_topics}},
	};
}

sub _load_spec {
	my $self = shift;

	$self->{spec} = $self->_files->read_json($self->{spec_path});
	Tavola::Project::Spec::Validator->validate($self->{spec});
	return;
}

sub _files {
	my $self = shift;
	$self->{files} ||= Tavola::Project::Spec::Files->new(spec_path => $self->{spec_path});
	return $self->{files};
}

sub _paths {
	my $self = shift;
	return Tavola::Project::Spec::Paths->new(config => $self->{config});
}

sub _print_plan {
	my $self = shift;
	my $spec = $self->{spec};
	my $tables = scalar @{$spec->{schema}->{tables}};
	my $procedures = scalar @{$spec->{schema}->{procedures}};
	my $roles = scalar @{$spec->{roles}};
	my $components = scalar @{$spec->{components}};
	my $actions = 0;

	for my $component (@{$spec->{components}}) {
		$actions++ if @{$component->{public} || []};
		$actions += scalar keys %{$component->{roles} || {}};
	}

	print "Dry run: valid project spec\n";
	print "owner: $spec->{owner}->{login}\n";
	print "project: $spec->{project}->{name}\n";
	print "planned inserts: 1 member if missing, 1 project, 1 datasource, $tables tables, $procedures procedures, $roles roles, $components components, $actions action rows\n";
	print "replace: " . ($self->{replace} ? "yes" : "no") . "\n";
	return;
}

1;
