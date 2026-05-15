use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../../perl";

use JSON qw(decode_json encode_json);
use Test::More;

use Tabilet::Project::ComponentJSON;

{
	package Local::Files;

	sub new {
		my ($class, %files) = @_;
		return bless \%files, $class;
	}

	sub read_text {
		my ($self, $path) = @_;
		die "missing fixture $path\n" unless exists $self->{$path};
		return $self->{$path};
	}
}

my $spec = {
	project => {
		publicRole => 'p',
	},
};
my $table = {
	current_key => 'widget_id',
	current_id_auto => 'widget_id',
	insert_pars => [ qw(name created) ],
	edit_pars => [ qw(widget_id name created) ],
	update_pars => [ qw(widget_id name) ],
	topics_pars => [ qw(widget_id name created) ],
};
my $component = {
	name => 'widget',
	table => 'widget',
	public => [ 'topics' ],
	roles => {
		a => [ qw(startnew insert edit update topics) ],
	},
};

my $builder = Tabilet::Project::ComponentJSON->new(spec => $spec, files => Local::Files->new());
my $generated = decode_json($builder->encode($component, $table));
is($generated->{current_table}, 'widget', 'generated component JSON validates and encodes');
is_deeply($generated->{insert_pars}, [ qw(name created) ], 'generated component JSON preserves params');

my $override = {
	actions => {
		topics => { groups => [ 'p', 'a' ] },
		startnew => { groups => [ 'a' ], options => [ qw(no_db no_method) ] },
	},
	current_table => 'widget',
	current_key => 'widget_id',
	insert_pars => [ qw(name created) ],
	edit_pars => [ qw(widget_id name created) ],
	update_pars => [ qw(widget_id name) ],
	topics_pars => [ qw(widget_id name created) ],
};

my $inline = Tabilet::Project::ComponentJSON->new(spec => $spec, files => Local::Files->new())
	->encode({ %$component, componentJson => $override }, $table);
is_deeply(decode_json($inline), $override, 'valid inline componentJson hash is accepted');

my $file_text = JSON->new->canonical->pretty->encode($override);
my $file = Tabilet::Project::ComponentJSON->new(
	spec => $spec,
	files => Local::Files->new('component.json' => $file_text),
)->encode({ %$component, componentJsonFile => 'component.json' }, $table);
is($file, $file_text, 'valid componentJsonFile text is accepted unchanged');

like(
	_error_for({ %$component, componentJson => { %$override, actions => undef } }),
	qr/actions must be an object/,
	'invalid actions override is rejected',
);

like(
	_error_for({ %$component, componentJson => { %$override, insert_pars => 'name' } }),
	qr/insert_pars must be an array/,
	'invalid parameter override is rejected',
);

like(
	_error_for({ %$component, componentJson => { %$override, current_key => undef } }),
	qr/current_key must be a string/,
	'invalid current_key override is rejected',
);

like(
	_error_for({ %$component, componentJson => '{bad json' }),
	qr/Invalid component JSON override.*componentJson/,
	'invalid inline JSON string is rejected',
);

my $bad_file_builder = Tabilet::Project::ComponentJSON->new(
	spec => $spec,
	files => Local::Files->new('bad.json' => encode_json({ %$override, topics_pars => {} })),
);
my $bad_file_error = eval {
	$bad_file_builder->encode({ %$component, componentJsonFile => 'bad.json' }, $table);
	1;
} ? '' : $@;
like($bad_file_error, qr/topics_pars must be an array/, 'invalid componentJsonFile is rejected');

done_testing();

sub _error_for {
	my $component = shift;
	my $error = eval {
		Tabilet::Project::ComponentJSON->new(spec => $spec, files => Local::Files->new())
			->encode($component, $table);
		1;
	} ? '' : $@;
	return $error;
}
