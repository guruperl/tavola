use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON qw(decode_json);
use Test::More;

use Tabilet::Project::Exporter;
use Tabilet::Project::Spec;

plan skip_all => 'set TABILET_RUN_DB_PARITY=1 to run metadata DB import/export parity test'
	unless $ENV{TABILET_RUN_DB_PARITY};

my $repo = abs_path("$Bin/..");
my $config = $ENV{TABILET_DB_PARITY_CONFIG} || "$repo/conf/config.json";
my $spec_path = $ENV{TABILET_DB_PARITY_SPEC} || "$repo/specs/smoke.project.json";
my $tmp = tempdir('tabilet-db-parity-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $spec = _read_json($spec_path);

my $direct = File::Spec->catdir($tmp, 'direct');
my $db_export = File::Spec->catdir($tmp, 'db-export');

my ($one, $other) = Tabilet::Project::Spec->new(
	config_path => $config,
	spec_path => $spec_path,
)->export_data();

Tabilet::Project::Exporter->new(
	config_path => $config,
	lang => 'php',
	data => [ $one, $other ],
	web_ui => 0,
	asset_root => $repo,
)->write_dir($direct, 1);

_quiet(sub {
	Tabilet::Project::Spec->new(
		config_path => $config,
		spec_path => $spec_path,
		replace => 1,
	)->run();
});

Tabilet::Project::Exporter->new(
	config_path => $config,
	owner => $spec->{owner}->{login},
	project => $spec->{project}->{name},
	lang => 'php',
	web_ui => 0,
	asset_root => $repo,
)->write_dir($db_export, 1);

my $direct_api = _read_json("$direct/api.json");
my $db_api = _read_json("$db_export/api.json");

is_deeply($db_api, $direct_api, 'DB-backed export api.json matches direct spec generation');

done_testing();

sub _read_json {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $json = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return decode_json($json);
}

sub _quiet {
	my $code = shift;
	open my $oldout, '>&', \*STDOUT or die "Cannot dup STDOUT: $!";
	open STDOUT, '>', File::Spec->devnull or die "Cannot redirect STDOUT: $!";
	my $ok = eval {
		$code->();
		1;
	};
	my $err = $@;
	open STDOUT, '>&', $oldout or die "Cannot restore STDOUT: $!";
	die $err unless $ok;
	return;
}
