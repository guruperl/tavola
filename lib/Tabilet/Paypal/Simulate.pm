package Tabilet::Paypal::Simulate;

use strict;
use JSON;
use Data::Dumper;

use Tabilet::Paypal::REST;
use vars qw(@ISA);
@ISA = qw(Tabilet::Paypal::REST);

__PACKAGE__->setup_accessors(
    target   => "/v1/notifications/simulate-event",
    idname   => "id",
);

sub insert {
	my $self = shift;
	my $query = shift;

	return "Please specify URL or webhook_id" unless ($query->{url} || $query->{webhook_id});
	# "3RP84656KD872633C"
	# "PAYMENT.AUTHORIZATION.CREATED"
	$query->{event_type} = "BILLING.SUBSCRIPTION.CREATED";
	$query->{resource_version} = "1.0";

    return $self->SUPER::insert($query);
}

1;
