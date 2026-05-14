package Tabilet::Webhook::Filter;

use strict;
use JSON;
use Tabilet::Paypal::Signature;
use Tabilet::Filter;
use vars qw(@ISA);

@ISA=('Tabilet::Filter');

sub clean_t {
	my $t = shift; $t =~ s/T/ /; $t =~ s/Z//; return $t;
}   

sub preset {
	my $self = shift;
	my $err  = $self->SUPER::preset(@_);
	return $err if $err;

	my $ARGS   = $self->{ARGS};
	my $r      = $self->{R};
	my $who    = $ARGS->{g_role};
	my $action = $ARGS->{g_action};

	if ($action eq 'insert') {
		my $p = Tabilet::Paypal::Signature->new(%{$self->{CUSTOM}->{PAYPAL}});
		$err = $p->init_request_bearer() and return $err;
		my $query = {webhook_id => $self->{CUSTOM}->{WEBHOOK}};
		$query->{auth_algo}        = $r->http("PAYPAL-AUTH-ALGO");
		$query->{cert_url}         = $r->http("PAYPAL-CERT-URL");
		$query->{transmission_id}  = $r->http("PAYPAL-TRANSMISSION-ID");
		$query->{transmission_sig} = $r->http("PAYPAL-TRANSMISSION-SIG");
		$query->{transmission_time}= $r->http("PAYPAL-TRANSMISSION-TIME");
		$query->{webhook_event}->{$_} = $ARGS->{$_} for (qw(id create_time resource_type event_type summary resource));
		$err = $p->insert($query);
		return $err if $err;
		$ARGS->{verification} = $p->{LISTS}->{verification_status};
		return 3001 unless ($ARGS->{verification} && $ARGS->{verification} eq 'SUCCESS');
		$ARGS->{$_} = $query->{$_} for (qw(webhook_id auth_algo cert_url transmission_id transmission_sig transmission_time));
		$ARGS->{resource_id} = $ARGS->{resource}->{id};
		$ARGS->{resource} = encode_json($ARGS->{resource});
		$ARGS->{create_time} = clean_t($ARGS->{create_time});
		$ARGS->{transmission_time} = clean_t($ARGS->{transmission_time});
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
    my $other = $form->{OTHER};

	if ($action eq 'insert' and $ARGS->{resource_type} eq 'subscription') {
		$err = $form->do_sql(
"UPDATE member m
INNER JOIN paypal_subscription s USING (memberid)
SET m.subscription_type = SUBSTRING(?,22), m.subscription_time = NOW()
WHERE s.subscriptionID = ?", $ARGS->{event_type}, $ARGS->{resource_id});
		return $err if $err;
	}

	return;
}

1;
