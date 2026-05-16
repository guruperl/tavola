package Tavola::Project::Spec;

use strict;
use warnings;

use Tavola::Project::Spec::Files;
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

1;
