package Tabilet::Member::Filter;

use strict;
use JSON;
use Genelet::Utils;
use Extra::QuestionAnswer;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub check_member_password {
	my $password = shift;
	return 3102 unless $password;
	return 3123 unless ($password =~ /\d/ && $password =~ /[a-zA-Z]/);
	return 3124 unless (length($password) >= 6);
	return;
}

sub preset {
	my $self = shift;
	my $err  = $self->SUPER::preset(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	if ($who eq 'public' && $action eq 'ask') {
		return 3114 unless ($ARGS->{answer} eq encryptHTML($ARGS->{question}));
	} elsif ($who eq 'public' && $action eq 'insert') {
		return 3114 unless ($ARGS->{answer} eq encryptHTML($ARGS->{question}));
		return 3102 unless $ARGS->{passwd};
		$err = $self->check_password() and return $err;
		$ARGS->{active} = 'First';
	} elsif ($who eq 'member' && $action eq 'update') {
		foreach my $key (keys %$ARGS) {
			delete $ARGS->{$key} if (grep {$key eq $_} qw(passwd active type_id created ip paycard));
		}
	} elsif ($action eq 'verify') {
		return 3111 unless $ARGS->{tkt};
		$ARGS->{stamp} = Genelet::Utils::get_tokentime($ARGS->{tkt});
		return 3112 unless $self->check_sign_open($ARGS->{tkt}, $ARGS->{memberid});
		return 3113 if ((time()-$ARGS->{stamp}) > 30*24*3600);
	} elsif ($action eq 'reset_pass') {
		return check_member_password($ARGS->{newpasswd});
	} elsif ($action eq 'changepass') {
		return check_member_password($ARGS->{passwd});
	} elsif ($action eq 'changeemail') {
		return 3102 unless ($ARGS->{newemail} eq $ARGS->{confirmemail});
		delete $ARGS->{confirmemail};
	} elsif ($who eq 'a' && $action eq 'topics') {
		$ARGS->{sortby} = 'created';
	}

	return;
}

sub before {
	my $self = shift;
	my $err  = $self->SUPER::before(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	my ($form, $extra, $nextextras) = @_;

	if ($action eq 'callback_github') {
		my $ticket = $self->{DBIS}->{"member"}->{"github"};
		my $github = $self->{CUSTOM}->{GITHUB} || {};
		$ticket->{CLIENT_ID}     = $github->{client_id} if $github->{client_id};
		$ticket->{CLIENT_SECRET} = $github->{client_secret} if $github->{client_secret};
		$ticket->{CALLBACK_URL}  = $github->{callback_url} if $github->{callback_url};
		$ticket->{SQL}     = "proc_github";
		$ticket->{IN_PARS} = ["memberid", "typeid", "in_login", "id", "login", "name", "bio", "company", "url", "repos_url", "html_url", "firstname", "lastname", "email", "access_token"];
		my $saved = $ticket->get_cookie($ticket->{PROVIDER_NAME});
		if ($saved) {
			my $hash = decode_json($saved);
			$ticket->{uc $_} = $hash->{$_} for (keys %$hash);
			$ticket->set_cookie_expired($ticket->{PROVIDER_NAME});
		}
		$err = $ticket->authenticate($ARGS->{code},undef,undef,$ARGS->{state});
		return $err if $err;
	} elsif ($action eq 'insert' || $action eq 'insert_github') {
		$err = $form->existing("login", $ARGS->{login}, "member") ||
			$form->randomid([100000,900000], 10, "memberid", "member");
		return $err if $err;
		$ARGS->{groupid} = $ARGS->{memberid};
	} elsif ($who eq 'admin' && $action eq 'topics' && $ARGS->{u}) {
		if ($ARGS->{u} eq 'created') {
			return 3005 unless ($ARGS->{d1} && $ARGS->{d2});
			$extra->{"_gsql"} = "created >= '$ARGS->{y1}-$ARGS->{m1}-$ARGS->{d1} 00:00:01' AND created <= '$ARGS->{y2}-$ARGS->{m2}-$ARGS->{d2} 23:59:59'";
		} else {
			return 3006 unless $ARGS->{v};
			if ($ARGS->{u} eq 'login') {
				$extra->{"_gsql"} = "m.login LIKE '" .$ARGS->{v} ."\%'";
			} elsif ($ARGS->{u} eq 'firstname') {
				$extra->{"_gsql"} = "(m.firstname LIKE '\%" .$ARGS->{v} ."\%')";
			} elsif ($ARGS->{u} eq 'lastname') {
				$extra->{"_gsql"} = "(m.lastname LIKE  '\%" .$ARGS->{v} ."\%')";
			} else {
				$extra->{"_gsql"} = "m.".$ARGS->{u} ." LIKE '" .$ARGS->{v} ."\%'";
			}
		}
	}

	return;
}

sub after {
	my $self = shift;
	my $err  = $self->SUPER::after(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

    my ($form) = @_;
    my $lists = $form->{LISTS};

	if ($who eq 'member' && $action eq 'update') {
    	if ($ARGS->{relogin}) {
			$r->{"headers_out"}->{"Location"} = "logout";
			return 303;
    	}
	} elsif ($who eq 'admin' && $action eq 'loginas') {
        $form->{OTHER}->{loginas} = {
			Role  => 'member',
			Provider=>"db",
			Uri   => '../../member/en/project?action=topics',
			Login => $ARGS->{login},
			Extra => {m_isgroup=>1, groupid=>$ARGS->{memberid}},
        };
	} elsif ($who eq 'admin' && $action eq 'topics') {
		$ARGS->{m1} ||= (localtime())[4] + 1;
		$ARGS->{m2} ||= $ARGS->{m1};
	} elsif ($who eq 'public' && $action eq 'insert') {
        $ARGS->{Server_url} = $self->{SERVER_URL};
        $ARGS->{Script} = $self->{SCRIPT};
		$ARGS->{tkt} = $self->sign_open($ARGS->{_gtime}, $ARGS->{memberid});
        $form->{OTHER}->{_smtp} = {
			To      => $ARGS->{email},
			Subject => "Welcome to Tabilet Online Service",
			File    => "insert.mail.".$ARGS->{_gtag},
        }
	} elsif ($who eq 'public' && $action eq 'insert_github') {
		my $ticket = $self->{DBIS}->{"member"}->{"github"};
		my $github = $self->{CUSTOM}->{GITHUB} || {};
		my $callback_url = $github->{callback_url};
		$ticket->{CLIENT_ID} = $github->{client_id} if $github->{client_id};
		$ticket->{CALLBACK_URL} = $callback_url if $callback_url;
		$self->{R}->{headers_out}->{"Location"} = $ticket->build_authorize($callback_url, $ARGS->{_gtime}, $self, '{"typeid":'.($ARGS->{typeid}||4).',"in_login":"'.$ARGS->{login}.'", "memberid":'.$ARGS->{memberid}.'}', $self->{SCRIPT}."/member/en/project?action=topics");
		return 303;
	} elsif ($who eq 'public' && $action eq 'ask') {
        $form->{OTHER}->{_smtp} = {
			To      => "peterbi\@gmail.com",
			Subject => "Someone is asking for Tabilet",
			Content => join("\n\n", map {$ARGS->{$_}} qw(message email phone)),
        }
	}

	return;
}

1;
