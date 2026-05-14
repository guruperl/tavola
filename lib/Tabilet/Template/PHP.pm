package Tabilet::Template::PHP;

use strict;
use Tabilet::Template::Base;
use vars qw($AUTOLOAD @ISA);
@ISA = ('Tabilet::Template::Base');

sub table_style {
	my $self = shift;

	my $str = shift;
	return qq~<style>
table { border-collapse: collapse; $str }
th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
tr:hover {background-color:#f5f5f5;}
</style>
~;
}

sub login {
	my $self = shift;
	my $default = shift;

	my $r = $self->{R};

	return qq~<!doctype html>
<html lang="en">
	<head>
	</head>
	<body>
<h3>{{ error_code }}</h3>
<FORM id="~.$r.qq~_login" method=post action="login">
<input type=hidden name="go_uri" value="{{ go_uri }}">
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

sub startnew {
	my $self = shift;
	my ($is_insert) = @_;

	my $r = $self->{R};
	my $c = $self->{C};
	my $pars = $self->{PARS};

	my $str = $self->table_style().qq~
            <form name="$r-$c-insert" method=post action="$c">
			<input type=hidden name=action value="insert">
<table>
~;
	for my $par (@$pars) {
		$str .= "<tr><th>".ucfirst($par) . qq~:</th><td> <INPUT TYPE="TEXT" name="$par"></td></tr>
~;
	}
	$str .= qq~</table>
<button TYPE="SUBMIT"> Add Now </button>
            </form>
~;
	return $str;
}

sub edit {
	my $self = shift;
	my ($is_update) = @_;

	my $r = $self->{R};
	my $c = $self->{C};
	my $uid = $self->{UID};
	my $pars = $self->{PARS};

	my $str = $self->table_style().qq~{% set item = edit[0] %}
~;
	if ($is_update) {
		$str .= qq~
            <form name="form-$r-$c-update" method=post action="$c">
			<input type=hidden name=action value="update">
			<input type=hidden name=$uid value="{{ $uid }}">
<table>
~;
		for my $par (@$pars) {
			if ($par eq $uid) {
				$str .= "<tr><th>" . ucfirst($par) . qq~:</th><td> {{ item.$par }}</td></tr>
~;
			} else {
				$str .= "<tr><th>" . ucfirst($par) . qq~:</th><td> <INPUT TYPE="TEXT" name="$par" value="{{ item.$par }}"></td></tr>
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
			$str .= "<tr><th>" . ucfirst($par) . qq~:</th><td> {{ item.$par }}</td></tr>
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
{% for item in topics %}<tr>
~;
	for my $par (@$pars) {
		if ($is_edit and ($par eq $uid)) {
			$str .= qq~<td><a href="$c?action=edit&$uid={{ item.$par }}">{{ item.$par }}</a></td>
~;
		} else {
			$str .= qq~<td>{{ item.$par }}</td>
~;
		}
	}
	$str .= "<td>";
	$str .= qq~<a href="$c?action=delete&$uid={{ item.$uid }}">Delete</a>~ if $is_delete;
	$str .= qq~</td>
</tr>
{% endfor %}</tbody>
</table>
~;
	$str .= qq~<p><a href="$c?action=startnew">Add New</a></p>\n~ if $is_startnew;
	return $str;
}

1;
