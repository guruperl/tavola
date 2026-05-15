package Tabilet::Project::Spec::Paths;

use strict;
use warnings;

sub new {
	my ($class, %args) = @_;
	return bless {
		config => $args{config} || {},
	}, $class;
}

sub project_paths {
	my ($self, $project, $owner) = @_;
	my $custom = ($self->{config} && $self->{config}->{Custom}) ? $self->{config}->{Custom} : {};
	my $root = $project->{root}
		|| ($custom->{USER_root} ? "$custom->{USER_root}/$owner->{login}" : "/home/user/tabilet/$owner->{login}");

	return {
		document_root => $project->{documentRoot} || "$root/www",
		server_url    => $project->{serverUrl} || ($custom->{USER_domain} ? "http://$owner->{login}.$custom->{USER_domain}" : 'http://localhost'),
		template      => $project->{template} || "$root/views",
		upload_dir    => $project->{uploadDir} || "$root/www/upload",
		log_file      => $project->{logFile} || "$root/logs/debug.log",
	};
}

1;
