package Tabilet::Paypal::Subscription;

use strict;
use JSON;

use Tabilet::Paypal::REST;
use vars qw(@ISA);
@ISA = qw(Tabilet::Paypal::REST);

__PACKAGE__->setup_accessors(
    target   => "/v1/billing/subscriptions",
    idname   => "id",
);

sub transactions {
	my $self = shift;
	my $query = shift;

	return $self->single("GET", undef, "transactions");
}

1;
