package Tabilet::Paypal::REST;

use strict;

use Genelet::REST;
use vars qw(@ISA);
@ISA = qw(Genelet::REST);

sub init_request_bearer {
	return shift->SUPER::init_request_bearer(
		"POST",
		{
		'Accept'          => "application/json",
		'Accept-Language' => "en_US",
		'Content-Type'    => "application/x-www-form-urlencoded",
		},
		"grant_type=client_credentials");
}

sub _single {
	my $self = shift;
	return $self->single("POST", @_);
}

sub activate {
	my $self = shift;
	my $query = shift;

	return $self->_single($query, "activate");
}

sub deactivate {
	my $self = shift;
	my $query = shift;

	return $self->_single($query, "deactivate");
}

sub cancel {
	my $self = shift;
	my $query = shift;

	return $self->_single($query, "cancel");
}

sub capture {
	my $self = shift;
	my $query = shift;

	return $self->_single($query, "capture");
}

sub revise {
	my $self = shift;
	my $query = shift;

	return $self->_single($query, "revise");
}

sub suspend {
	my $self = shift;
	my $query = shift;

	return $self->_single($query, "suspend");
}

1;
