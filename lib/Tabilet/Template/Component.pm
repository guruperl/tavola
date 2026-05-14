package Tabilet::Template::Component;

use strict;
use Genelet::Accessor;
use vars qw($AUTOLOAD @ISA);
@ISA = qw(Genelet::Accessor);

__PACKAGE__->setup_accessors(
    yes    => undef,
    uid    => "",
	logger => undef
);

# input
#       p
#         default: [comp, action]
#           comp1: yes: {action1=>pars1, action2=>pars2, ...}, uid: id_name
#       a
#         default: [comp, action, field_login, field_passwd, field_firstname, field_lastname]
#           comp1: yes: {action1=>pars1, action2=>pars2, ...}, uid: id_name
#
# output
# app.html central part, need generator/vue with landing role,comp,verb
#        p
#          header=>content_header.vue
#          footer=>content_footer.vue
#               comp1=>
#                    action1=>content_action1.vue
#                    action2=>content_action2.vue
#        a
#          header=>content_header.vue
#          login=>content_login.vue
#          footer=>content_footer.vue
#               comp1=>
#                    action1=>content_action1.vue
#                    action2=>content_action2.vue

			#my $vue = Tabilet::Vue->new(r=>$r, c=>$c, uid=>$self->{UID});
			#my $php = Tabilet::PHP->new(r=>$r, c=>$c, uid=>$self->{UID});
sub code {
	my $self = shift;
	my $r    = shift;
	my $c    = shift;
	my $vue  = shift;
	my $php  = shift;

	my $uid = $self->{UID};
	my $yess= $self->{YES};

	my $outp = {};
	my $hash = {};
	my $str  = "";
	for my $a (keys %$yess) {
		$vue->pars($yess->{$a});
		$php->pars($yess->{$a});
		my $html = qq~<p><em>$a</em> is completed.</p>~;
		if ($a eq 'startnew') {
			$hash->{$a} = exists($yess->{insert}) ? $vue->startnew() : "";
			$html       = exists($yess->{insert}) ? $php->startnew() : "";
			$str       .= "    '$r-$c-$a': httpVueLoader('./$r/$c/$a.vue'),\n";
		} elsif ($a eq 'topics') {
			$hash->{$a} = $vue->topics($yess->{edit}, exists($yess->{'delete'}), exists($yess->{'startnew'}));
			$html       = $php->topics($yess->{edit}, exists($yess->{'delete'}), exists($yess->{'startnew'}));
			$str       .= "    '$r-$c-$a': httpVueLoader('./$r/$c/$a.vue'),\n";
		} elsif ($a eq 'edit') {
			$hash->{$a} = $vue->edit(exists($yess->{update}));
			$html       = $php->edit(exists($yess->{update}));
			$str       .= "    '$r-$c-$a': httpVueLoader('./$r/$c/$a.vue'),\n";
		} else {
			$hash->{$a} = undef;
		}
		$outp->{$a} = qq~{{ include("header.html") }}

~. $html . qq~

{{ include("footer.html") }}
~;
	}

	return $str, $hash, $outp;
}

1;
