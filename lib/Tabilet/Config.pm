package Tabilet::Config;

use strict;
use Genelet::Dispatch;
use Exporter qw(import);

our @EXPORT_OK = qw(load_config expand_env);

sub load_config {
	my $path = shift;
	return expand_env(Genelet::Dispatch::get_hash($path));
}

sub expand_env {
	my $value = shift;

	if (ref($value) eq 'HASH') {
		$value->{$_} = expand_env($value->{$_}) for keys %$value;
		return $value;
	}
	if (ref($value) eq 'ARRAY') {
		$value->[$_] = expand_env($value->[$_]) for 0 .. $#$value;
		return $value;
	}
	if (defined($value) && !ref($value) && $value =~ /\A\$\{([A-Z_][A-Z0-9_]*)\}\z/) {
		my $name = $1;
		die "Missing required environment variable $name\n" unless defined $ENV{$name};
		return $ENV{$name};
	}

	return $value;
}

1;
