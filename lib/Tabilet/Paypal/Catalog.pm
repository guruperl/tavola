package Tabilet::Paypal::Catalog;

use strict;

use Tabilet::Paypal::REST;
use vars qw(@ISA);
@ISA = qw(Tabilet::Paypal::REST);

__PACKAGE__->setup_accessors(
    target   => "/v1/catalogs/products",
    idname   => "id",
);

sub insert {
    my $self  = shift;
    my $query = shift;
   	$query->{category} = "SOFTWARE";
   	$query->{type}     = "SERVICE";
   	$query->{home_url} = "https://www.tabilet.com/price.html";

    return $self->SUPER::insert($query);
}

1;
