package Tabilet::Subscription::Filter;

use strict;
use Data::Dumper;
use JSON;
use Tabilet::Paypal::Subscription;
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
		my $p = Tabilet::Paypal::Subscription->new(%{$self->{CUSTOM}->{PAYPAL}});
		$err = $p->init_request_bearer() || $p->edit({id=>$ARGS->{subscriptionID}});
		return $err if $err;
		my $lists = $p->{LISTS};
		if ($lists) {
			$ARGS->{status_update_time} = clean_t($lists->{status_update_time});
			$ARGS->{start_time}         = clean_t($lists->{start_time});
			$ARGS->{status}             = $lists->{status};
			$ARGS->{plan_id}            = $lists->{plan_id};
			$ARGS->{shipping_amount}    = $lists->{shipping_amount}->{value};
			$ARGS->{$_} = encode_json($lists->{$_}) for (qw(subscriber billing_info links));
		}
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

	return;
}

1;
