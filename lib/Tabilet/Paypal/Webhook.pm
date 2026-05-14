package Tabilet::Paypal::Webhook;

use strict;
use JSON;
use Data::Dumper;

use Tabilet::Paypal::REST;
use vars qw(@ISA);
@ISA = qw(Tabilet::Paypal::REST);

__PACKAGE__->setup_accessors(
    target   => "/v1/notifications/webhooks",
    idname   => "id",
);


sub insert {
	my $self = shift;
	my $query = shift;

	return "Please specify URL" unless $query->{url};
	
	$query->{event_type} = decode_json(qq~[
		{ "name": "BILLING.SUBSCRIPTION.ACTIVATED" },
		{ "name": "BILLING.SUBSCRIPTION.CANCELLED" },
		{ "name": "BILLING.SUBSCRIPTION.CREATED" },
		{ "name": "BILLING.SUBSCRIPTION.EXPIRED" },
		{ "name": "BILLING.SUBSCRIPTION.PAYMENT.FAILED" },
		{ "name": "BILLING.SUBSCRIPTION.RE-ACTIVATED" },
		{ "name": "BILLING.SUBSCRIPTION.RENEWED" },
		{ "name": "BILLING.SUBSCRIPTION.SUSPENDED" },
		{ "name": "BILLING.SUBSCRIPTION.UPDATED" }
	]~) unless ($query->{event_type});

	$query->{resource_version} = "1.0";

    return $self->SUPER::insert($query);
}

1;
