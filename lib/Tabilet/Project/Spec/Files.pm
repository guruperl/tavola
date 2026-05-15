package Tabilet::Project::Spec::Files;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use JSON qw(decode_json);

sub new {
	my ($class, %args) = @_;
	return bless {
		spec_path => $args{spec_path},
	}, $class;
}

sub read_json {
	my ($self, $path) = @_;
	die "Missing JSON path\n" unless $path;

	open my $fh, '<', $path or die "Cannot open $path: $!\n";
	local $/;
	my $json = <$fh>;
	close $fh or die "Cannot close $path: $!\n";

	return decode_json($json);
}

sub read_text {
	my ($self, $path) = @_;
	my $resolved = $self->resolve_path($path);
	open my $fh, '<', $resolved or die "Cannot open $path: $!\n";
	local $/;
	my $text = <$fh>;
	close $fh or die "Cannot close $path: $!\n";
	return $text;
}

sub statement {
	my ($self, $item) = @_;
	return $item->{statement} if $item->{statement};
	return $self->read_text($item->{statementFile});
}

sub resolve_path {
	my ($self, $path) = @_;
	return $path if File::Spec->file_name_is_absolute($path);

	my $spec_dir = dirname(abs_path($self->{spec_path}));
	my $from_spec = File::Spec->catfile($spec_dir, $path);
	return $from_spec if -e $from_spec;

	my $from_cwd = File::Spec->catfile(File::Spec->curdir, $path);
	return $from_cwd if -e $from_cwd;

	return $from_spec;
}

1;
