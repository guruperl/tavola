package Tavola::Template::Perl;

use strict;
use Tavola::Template::PHP;
use vars qw($AUTOLOAD @ISA);
@ISA = qw(Tavola::Template::PHP);

sub login {
	my $self = shift;
	my $default = shift;

	my $r = $self->{R};

	return qq~<!doctype html>
<html lang="en">
	<head>
	</head>
	<body>
<h3>[% error_code %]</h3>
<FORM id="~.$r.qq~_login" method=post action="login">
<input type=hidden name="go_uri" value="[% go_uri %]">
~.$self->table_style().qq~
<table>
<tr><th>Login:</th><td> <INPUT TYPE="TEXT"     name="~.$default->[2].qq~" /></td></tr>
<tr><th>Password:</th><td> <INPUT TYPE="PASSWORD" name="~.$default->[3].qq~" /></td></tr>
</table>
<button TYPE="SUBMIT"> Sign In Now </button>
</FORM>
	</body>
</html>
~;
}

sub edit {
	my $self = shift;
	my ($is_update) = @_;

	my $r = $self->{R};
	my $c = $self->{C};
	my $uid = $self->{UID};
	my $pars = $self->{PARS};

	my $str = $self->table_style().qq~[% SET item = edit.0 %]
~;
	if ($is_update) {
		$str .= qq~
            <form name="form-$r-$c-update" method=post action="$c">
			<input type=hidden name=action value="update">
			<input type=hidden name=$uid value="[% $uid %]">
<table>
~;
		for my $par (@$pars) {
			if ($par eq $uid) {
				$str .= "<tr><th>" . ucfirst($par) . qq~:</th><td> [% item.$par %]</td></tr>
~;
			} else {
				$str .= "<tr><th>" . ucfirst($par) . qq~:</th><td> <INPUT TYPE="TEXT" name="$par" value="[% item.$par %]"></td></tr>
~;
			}
		}
		$str .= qq~</table>
<button TYPE="SUBMIT"> Update Now </button>
            </form>
~;
	} else {
		$str .= qq~<table>
~;
		for my $par (@$pars) {
			$str .= "<tr><th>" . ucfirst($par) . qq~:</th><td> [% item.$par %]</td></tr>
~;
		}
		$str .= qq~</table>
~;
	}
	return $str;
}

sub topics {
	my $self = shift;
	my ($is_edit, $is_delete, $is_startnew) = @_;

	my $r = $self->{R};
	my $c = $self->{C};
	my $uid = $self->{UID};
	my $pars = $self->{PARS};

	my $str = $self->table_style("width: 100%").qq~<table>
<thead><tr>
~;
	for my $par (@$pars) {
		$str .= qq~<th>~.ucfirst($par).qq~</th>
~;
	}
	$str .= qq~<th></th>
</tr>
</thead>
<tbody>
[% FOREACH item=topics %]<tr>
~;
	for my $par (@$pars) {
		if ($is_edit and ($par eq $uid)) {
			$str .= qq~<td><a href="$c?action=edit&$uid=[% item.$par %]">[% item.$par %]</a></td>
~;
		} else {
			$str .= qq~<td>[% item.$par %]</td>
~;
		}
	}
	$str .= "<td>";
	$str .= qq~<a href="$c?action=delete&$uid=[% item.$uid %]">Delete</a>~ if $is_delete;
	$str .= qq~</td>
</tr>
</tbody>
</table>
~;
	$str .= qq~<p><a href="$c?action=startnew">Add New</a></p>\n~ if $is_startnew;
	return $str;
}

1;
