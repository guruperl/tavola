use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use JSON qw(decode_json encode_json);
use Test::More;

use Tavola::Generator::PHP;
use Tavola::Generator::Perl;
use Tavola::Project::Exporter;
use Tavola::Project::Spec;
use Tavola::Project::Spec::Validator;

my $repo = abs_path("$Bin/..");

is(
	Tavola::Generator::PHP->new(project => _project(dbtype => 'MySQL'))->config_hash()->{Db}->[0],
	'mysql:host=127.0.0.1;port=3306;dbname=app',
	'MySQL datasource creates PDO mysql DSN',
);

is(
	Tavola::Generator::PHP->new(project => _project(dbtype => 'PostgreSQL', port => 5432))->config_hash()->{Db}->[0],
	'pgsql:host=127.0.0.1;port=5432;dbname=app',
	'PostgreSQL datasource creates PDO pgsql DSN',
);

is(
	Tavola::Generator::PHP->new(project => _project(dbtype => 'SQLite3', dbname => 'data/app.sqlite'))->config_hash()->{Db}->[0],
	'sqlite:data/app.sqlite',
	'SQLite3 datasource creates PDO sqlite DSN',
);

like(
	Tavola::Generator::Perl->new(project => _project(dbtype => 'PostgreSQL'))->project_model(),
	qr/use Genelet::Pg;/,
	'PostgreSQL Perl output uses Genelet::Pg',
);

like(
	Tavola::Generator::Perl->new(project => _project(dbtype => 'SQLite'))->project_model(),
	qr/use Genelet::SQLite;/,
	'SQLite Perl output uses Genelet::SQLite',
);

my $exporter = Tavola::Project::Exporter->new();
my $procedure = [{ procedure_name => 'proc_login', statement => 'CREATE PROCEDURE proc_login() SELECT 1' }];
like($exporter->_procedure_init_sql($procedure, 'MySQL'), qr/DELIMITER \/\/.*proc_login\(\) SELECT 1\/\/.*DELIMITER ;/s, 'MySQL init keeps delimiter procedure wrapper');
like($exporter->_procedure_init_sql($procedure, 'PostgreSQL'), qr/DROP PROCEDURE IF EXISTS proc_login;\nCREATE PROCEDURE proc_login\(\) SELECT 1;/, 'PostgreSQL init emits plain procedure DDL');
unlike($exporter->_procedure_init_sql($procedure, 'SQLite'), qr/DROP PROCEDURE|DELIMITER/, 'SQLite init omits stored procedure DDL');

my $sqlite_spec = _sqlite_spec();
ok(eval { Tavola::Project::Spec::Validator->validate($sqlite_spec); 1 }, 'SQLite datasource validates without host/user/password');

like(
	_error_for({ %$sqlite_spec, datasource => { type => 'Oracle', nickname => 'bad', database => 'x' } }),
	qr/Unsupported datasource type 'Oracle'/,
	'unsupported datasource type is rejected',
);

my $tmp = tempdir('tavola-datasource-test-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $spec_path = File::Spec->catfile($tmp, 'sqlite.project.json');
_write_text($spec_path, JSON->new->canonical->pretty->encode($sqlite_spec));

my ($one, $other) = Tavola::Project::Spec->new(
	config_path => "$repo/conf/config.json",
	spec_path => $spec_path,
)->export_data();

for my $lang (qw(php perl)) {
	my $out = File::Spec->catdir($tmp, $lang);
	Tavola::Project::Exporter->new(
		config_path => "$repo/conf/config.json",
		lang => $lang,
		data => [ $one, $other ],
		web_ui => 0,
		asset_root => $repo,
	)->write_dir($out, 1);

	my $config = _read_json(File::Spec->catfile($out, 'conf', 'config.json'));
	is($config->{Db}->[0], 'sqlite:data/app.sqlite', "$lang generated SQLite config keeps PDO sqlite DSN");
}

like(
	_read_text(File::Spec->catfile($tmp, 'perl', 'lib', 'SqliteApp', 'Model.pm')),
	qr/use Genelet::SQLite;/,
	'generated SQLite Perl project model uses Genelet::SQLite',
);

system($^X, '-Ilib', "-I$repo/lib", "-I$repo/../perl", '-c', File::Spec->catfile($tmp, 'perl', 'script', 'app')) == 0
	or die "generated SQLite Perl app did not compile\n";

done_testing();

sub _project {
	my %override = @_;
	return {
		Document_root => '/tmp/app/www',
		Project => 'App',
		Server_url => 'http://app.test',
		Script => '/app.php',
		Pubrole => 'p',
		Template => '/tmp/app/views',
		Uploaddir => '/tmp/app/upload',
		Log_file => '/tmp/app/logs/debug.log',
		dbtype => 'MySQL',
		dbname => 'app',
		host => '127.0.0.1',
		port => 3306,
		dbuser => '${APP_DB_USER}',
		dbpass => '${APP_DB_PASSWORD}',
		%override,
	};
}

sub _sqlite_spec {
	return {
		version => 1,
		owner => {
			login => 'sqlite',
			email => 'sqlite@example.test',
			typeid => 1,
		},
		project => {
			name => 'SqliteApp',
			script => '/sqlite/app.php',
			publicRole => 'p',
			default => {
				component => 'item',
				action => 'topics',
			},
		},
		datasource => {
			type => 'SQLite3',
			nickname => 'sqlite',
			path => 'data/app.sqlite',
		},
		schema => {
			tables => [
				{
					name => 'item',
					primaryKey => 'item_id',
					autoKey => 'item_id',
					statement => 'CREATE TABLE item (item_id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, created TEXT)',
					insert => [ qw(title created) ],
					edit => [ qw(item_id title created) ],
					update => [ qw(item_id title) ],
					topics => [ qw(item_id title created) ],
				},
			],
			procedures => [],
		},
		roles => [],
		components => [
			{
				name => 'item',
				description => 'SQLite test items',
				table => 'item',
				public => [ 'topics' ],
			},
		],
		overlays => {},
	};
}

sub _error_for {
	my $spec = shift;
	return eval {
		Tavola::Project::Spec::Validator->validate($spec);
		1;
	} ? '' : $@;
}

sub _read_json {
	my $path = shift;
	return decode_json(_read_text($path));
}

sub _read_text {
	my $path = shift;
	open my $fh, '<', $path or die "Cannot open $path: $!";
	local $/;
	my $text = <$fh>;
	close $fh or die "Cannot close $path: $!";
	return $text;
}

sub _write_text {
	my ($path, $text) = @_;
	open my $fh, '>', $path or die "Cannot open $path: $!";
	print {$fh} $text;
	close $fh or die "Cannot close $path: $!";
	return;
}
