package Tabilet::Github;

use strict;
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common;
use Git::Repository;

use Genelet::Accessor;
use vars qw(@ISA);
@ISA = ('Genelet::Accessor');

__PACKAGE__->setup_accessors(
	github => undef,	
	api    => "https://api.github.com",
	owner  => "tabilet",
	top    => "/home/user/tabilet",
	body   => '',
	args   => undef,
	logger => undef,
);
	
sub request {
	my $self = shift;
	my $method = shift;
	my $uri = shift;
	my $data = shift;
	my $token = shift || $self->{GITHUB}->{token};

	$uri = $self->{API} . $uri;

	my $ua = LWP::UserAgent->new();
	$ua->default_header(Authorization => "token $token");
	$ua->default_header(Accept => "application/json");

	my $res;
	if ($method eq 'GET') {
		$res = ($data) ? $ua->get($uri, %$data) : $ua->get($uri);
	} elsif ($method eq 'DELETE') {	
		$res = ($data) ? $ua->delete($uri, %$data) : $ua->delete($uri);
	} elsif ($method eq 'PATCH') {
		$res = ($data) ? $ua->request(PATCH $uri, [%$data]) : $ua->request(PATCH $uri);
		#$res = ($data) ? $ua->patch($uri, $data) : $ua->patch($uri);
	} elsif ($method eq 'POST') {
		$res = $ua->post($uri, Content=>$data);
	} elsif ($method eq 'PUT') {
		$res = $ua->put($uri, Content=>$data);
	}
#$self->{LOGGER}->info($res->decoded_content);
	return $res->code() unless $res->is_success;
	$self->{BODY} = decode_json($res->decoded_content) if $res->decoded_content;
	return;
}

# find if user is a collaborator of tabilet's this repository
sub find_collaborator {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	my $err = $self->request("GET", "/repos/".$self->{OWNER}."/".$ARGS->{login}."/collaborators/".$ARGS->{git_login});
	if ($err) {
		return if ($err==404);
		return $err;
	}

	$ARGS->{is_coll} = 1;
	return;
}

# find if tabilet's user repository exists
sub find_remote {
	my $self = shift;
	my $ARGS = $self->{ARGS};
	
	my $err = $self->request("GET", "/repos/".$self->{OWNER}."/".$ARGS->{login});
	if ($err) {
		return if ($err==404);
		return $err;
	}

	$ARGS->{is_repo} = 1 if ($self->{BODY}->{name} eq $ARGS->{login});
	return;
}

# make a local git and push it to remote
# note that under FCGI, this failes due to "OPEN", so has to be CGI!
sub push {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $login = $ARGS->{login};
	my $root  = $self->{TOP} . "/" . $login;

	unless ($ARGS->{is_repo}) {
		my $err = $self->request('POST', "/user/repos", qq~{"name":"$login"}~);
		return $err if $err;
	}
	my $first = 0;
	unless (-d "$root/.git") {
		$first = 1;
		Git::Repository->run( init => $root ) unless (-d "$root/.git");
	}
	my $repo = Git::Repository->new( work_tree => $root );
	my $ret = $repo->run( add => '.' );
	$ret = $repo->run( commit => '-m', 'tabilet auto generated' );
	# home is /var/www, key is /var/www/.ssh/rsa_id
	if ($first) {
		$ret = $repo->run(remote => "add", "origin", "git\@github.com:".$self->{OWNER}."/$login.git");
		$ret = $repo->run("push" => "--set-upstream", "origin", "main");
	} else {
		$ret = $repo->run("push" => "origin", "main");
	}
	return;
}

sub erase {
	my $self = shift;
	my $ARGS = $self->{ARGS};

	my $login = $ARGS->{login};
	my $url = "/repos/".$self->{OWNER}."/".$ARGS->{login};
	return $self->request("DELETE", $url);
	#return $self->request("DELETE", "$url/collaborators/".$ARGS->{git_login});
}

# invite a collaborator with pull-only access
# if new invite and user has oauth2 access_token, accept the invite
sub invite {
	my $self = shift;
	my $hash = shift;
	my $ARGS = $self->{ARGS};

	my $login = $ARGS->{login};
	my $id;

	my $url = "/repos/".$self->{OWNER}."/".$ARGS->{login};

# check if already invited
$self->{LOGGER}->info("existing invitation");
	my $err = $self->request("GET", "$url/invitations");
	return $err if $err;
	if ($self->{BODY}) {
		foreach my $invite (@{$self->{BODY}}) {
			if ($invite->{inviter}->{login} eq $hash->{git_login}) {
$self->{LOGGER}->info("existing found");
				$id = $invite->{id};
				last;
			}
		}
	}
	unless ($id) {
$self->{LOGGER}->info("sending invitation");
		$err = $self->request('PUT', "$url/collaborators/".$hash->{git_login}, qq~{"permission": "pull"}~);
		return $err if $err;
		$id = $self->{BODY}->{id} if $self->{BODY};
	}
	if ($id && $hash->{access_token}) {
$self->{LOGGER}->info("accept invitation");
		$err = $self->request('PATCH', "/user/repository_invitations/$id", undef, $hash->{access_token});
		return $err if $err;
	}
	return;
}

1;
