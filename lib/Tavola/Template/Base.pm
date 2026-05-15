package Tavola::Template::Base;

use strict;
use Genelet::Accessor;
use vars qw(@ISA);
@ISA = qw(Genelet::Accessor);

__PACKAGE__->setup_accessors(
    r    => "",
    c    => "",
    uid  => "",
	pars => undef,
	logger => undef,
);

sub app { # app.html
	my $str = shift; # get it from project/filter/vues
	my ($role, $comp, $action) = @_; # landing	

	return qq~<!doctype html>
<html lang="en">
  <head>
    <script src="https://unpkg.com/vue"></script>
    <script src="https://unpkg.com/http-vue-loader"></script>
    <script src="/genelet.js"></script>
  </head>
<body>

<div id="app">
<component v-bind:is="headerComponent"></component>
<component v-bind:is="currentComponent" v-bind:names="names"></component>
<component v-bind:is="footerComponent"></component>
</div>

<script>

var \$scope = new VueGenelet({handler:"/app.php", "mime":"vue",
		"role":"$role", "comp":"$comp", "action":"$action"});
\$scope.start();

var vm = new Vue({
  el: '#app',
  data : \$scope,
  components: {
$str
  }
});
vm.\$scope = \$scope;

</script>

</body>
</html>
~;
}

sub index { # index.html
	my ($def_component, $def_action, $p_list, $a_list, $r_list) = @_; # landing

	my ($r, $c, $a);

	my $index1 = qq~
	<h5>Public Role <em>p</em></h5>
	<ul>
~;
	my $index2 = qq~
	<h5>Public Role <em>p</em></h5>
	<ul>
~;
	for my $hash (@$p_list) {
		$r = "p";
		$c = $hash->{name_component};
		$a = $hash->{action};
		$index1 .= qq~	<li>~.ucfirst($c).qq~: <a href="/app.php/$r/html/$c?action=$a">/app.php/$r/html/$c?action=$a</a>
~;
		$index2 .= qq~	<li>~.ucfirst($c).qq~: <a href="/app.html#/$r/$c?action=$a">/app.html#/$r/$c?action=$a</a>
~;
	}
	$index1 .= qq~	</ul>
~;
	$index2 .= qq~	</ul>
~;

	my $ref = {};
	foreach my $hash (@$a_list) {
		$r = "a";
		$c = $hash->{name_component};
		$a = "topics";
		push @{$ref->{$r}}, [$c, $a];
	}
	foreach my $hash (@$r_list) {
		$r = $hash->{name_role};
		$c = $hash->{name_component};
		$a = $hash->{action};
		push @{$ref->{$r}}, [$c, $a];
	}

	foreach my $r (sort keys %$ref) {
		$index1 .= qq~
	<p></p>
	<h5>Role <em>$r</em></h5>
	<ul>
	<li>Login will popup
~;
		$index2 .= qq~

	<p></p>
	<h5>Role <em>$r</em></h5>
	<ul>
	<li>Login will popup
~;
		foreach my $item (@{$ref->{$r}}) {
			$c = $item->[0];
			$a = $item->[1];
			$index1 .= qq~	<li>~.ucfirst($c).qq~: <a href="/app.php/$r/html/$c?action=$a">/app.php/$r/html/$c?action=$a</a>
~;
			$index2 .= qq~	<li>~.ucfirst($c).qq~: <a href="/app.html#/$r/$c?action=$a">/app.html#/$r/$c?action=$a</a>
~;
		}
		$index1 .= qq~	<li>Logout: <a href="/app.php/$r/html/logout">/app.php/$r/html/logout</a>
	</ul>
~;
		$index2 .= qq~	<li>Logout button: &lt;button \@click="logout('$r', 'logout', {role:'p', comp:'~.$def_component.qq~', action:'~.$def_action.qq~'})"&gt;Logout&lt;/button&gt;
	</ul>
~;
	}

	return qq~<!doctype html>
<html lang="en">
  <head>
	<meta charset="UTF-8">
  </head>
  <body>
    <h3>Web Site by Twig</h3>
    $index1
    <p> &nbsp; </p>
    <h3>VueJS HTML5 App using API</h3>
    $index2
  </body>
</html>
~;
}

1;
