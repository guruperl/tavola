package Tabilet::Paypal::Plan;

use strict;

use Tabilet::Paypal::REST;
use vars qw(@ISA);
@ISA = qw(Tabilet::Paypal::REST);

__PACKAGE__->setup_accessors(
    target   => "/v1/billing/plans",
    idname   => "id",
);

sub insert {
	my $self = shift;
	my $query = shift;

	return 3203 unless $query->{product_id};
	return 3204 unless $query->{billing_cycles};
	return 3205 unless $query->{payment_preferences};
	$query->{status} = "ACTIVE";

    return $self->SUPER::insert($query);
}

sub update_pricing {
	my $self = shift;
	my $query = shift;

	my $id = $query->{$self->{IDNAME}};
	return 1170 unless $id;
	$id = "/$id/update-pricing-schemes";
	delete $query->{$self->{IDNAME}};
=pod
{
  "pricing_schemes": [
    {
      "billing_cycle_sequence": 2,
      "pricing_scheme": {
        "fixed_price": {
          "value": "50",
          "currency_code": "USD"
        }
      }
    }
  ]
}
=cut
	return $self->talk("POST", $query, $id);
}

1;
