package Tavola::Template::Role;

use strict;
use Tavola::Template::Component;
use Tavola::Template::Vue;
use Tavola::Template::PHP;

use Genelet::Accessor;
use vars qw(@ISA);
@ISA = qw(Genelet::Accessor);

__PACKAGE__->setup_accessors(
    default => undef,
	comps   => undef,
	logger  => undef,
);

# input
#       p
#         default: [comp, action]
#           comp1: yes: {action1=>pars1, action2=>pars2, ...}, uid: id_name
#       a
#         default: [comp, action, field_login, field_passwd, field_firstname, field_lastname]
#           comp1: yes: {action1=>pars1, action2=>pars2, ...}, uid: id_name
#
# output
# app.html central part, need generator/vue with landing role,comp,verb
#        p
#          header=>content_header.vue
#          footer=>content_footer.vue
#               comp1=>
#                    action1=>content_action1.vue
#                    action2=>content_action2.vue
#        a
#          header=>content_header.vue
#          login=>content_login.vue
#          footer=>content_footer.vue
#               comp1=>
#                    action1=>content_action1.vue
#                    action2=>content_action2.vue

sub code {
	my $self = shift;
	my $r    = shift;
	my $pubrole = shift;
	my $vue  = Tavola::Template::Vue->new(r=>$r);
	my $php  = Tavola::Template::PHP->new(r=>$r);
	
	my $outp = {};
	my $hash = {};
	my $str  = "";

	$hash->{header} = qq~<template>
<h5>header</h5>
</template>
~;
	$outp->{header} = qq~<!doctype html>
<html lang="en">
	<head>
	</head>
	<body>
~;
	$hash->{footer} =  qq~<template>
<h5>footer</h5>
</template>
~;
	$outp->{footer} = qq~
	</body>
</html>
~;
	$str .= "    '$r-header': httpVueLoader('./$r/header.vue'),\n";
	$str .= "    '$r-footer': httpVueLoader('./$r/footer.vue'),\n";
	unless ($r eq $pubrole) {
		$hash->{login} = $vue->login($self->{DEFAULT});
		$outp->{login} = $php->login($self->{DEFAULT});
		$str .= "    '$r-login': httpVueLoader('./$r/login.vue'),\n";
	}

	for my $c (keys %{$self->{COMPS}}) {
		my $comp_obj = $self->{COMPS}->{$c};
		$vue->c($c);
		$php->c($c);
		$vue->uid($comp_obj->{UID});
		$php->uid($comp_obj->{UID});
		my @a = $comp_obj->code($r, $c, $vue, $php);
		$str .= $a[0];		
		$hash->{$c} = $a[1];
		$outp->{$c} = $a[2];
	}	

	return $str, $hash, $outp;
}

sub strToPars {
	my $str = shift;
	return unless $str;

	substr($str, 0,1) = "";
	substr($str,-1,1) = "";
	my $a;
	for my $item (split(/,/, $str)) {
		$item =~ s/^\s*"//;
		$item =~ s/"\s*$//;
		push @$a, $item;
	}
	return $a;
}

sub vues {
	my $one = shift;
	my $logger = shift;

	my $lists_component = $one->{component_topics};
	my $lists_role      = $one->{role_topics};
	my $lists_acl_pub   = $one->{role_pub_acl};
	my $lists_acl_role  = $one->{role_role_acl};

	my $input = {};
	# role p
	$input->{p} = Tavola::Template::Role->new(default=>[$one->{def_component}, $one->{def_action}], logger=>$logger);

    for my $item (@$lists_role) {    # all roles including a. no p
		my $role = Tavola::Template::Role->new(default=>[$item->{default_component}, $item->{default_action}, $item->{field_login}, $item->{field_passwd}, $item->{field_firstname}, $item->{field_lastname}], logger=>$logger);
		$input->{$item->{name_role}} = $role;
    }

    for my $item (@$lists_component) { # all components, for a only
		my $comp = Tavola::Template::Component->new(
			yes => {
				topics  =>strToPars($item->{topics_pars}),
				insert  =>strToPars($item->{insert_pars}),
				edit    =>strToPars($item->{edit_pars}),
				update  =>strToPars($item->{update_pars}),
				delete  =>undef,
				startnew=>strToPars($item->{insert_pars})},
			uid => $item->{current_key},
			logger => $logger,
		);
		$input->{a}->{COMPS}->{$item->{name_component}} = $comp;
    }

    $_->{name_role} = 'p' for @$lists_acl_pub; # components for p
    for my $item (@$lists_acl_pub, @$lists_acl_role) { # components for p and other roles, not a
        my @arrs = split ',', $item->{crud}, -1;
		my $yes = {};
        for my $v (@arrs) {
			if ($v eq 'startnew' and $item->{crud}=~/insert/) {
				$yes->{$v} = strToPars($item->{"insert_pars"});
			} else {
				$yes->{$v} = strToPars($item->{$v."_pars"});
			}
        }
		my $comp = Tavola::Template::Component->new(yes=>$yes, uid=>$item->{current_key}, logger => $logger);
        $input->{$item->{name_role}}->{COMPS}->{$item->{name_component}} = $comp;
    }


	my $str = "";
    my ($hash, $outp); 

	foreach my $r (keys %$input) {
		my $role_obj = $input->{$r};
		my @a = $role_obj->code($r, "p");
		$str .= $a[0];
		$hash->{$r} = $a[1];
		$outp->{$r} = $a[2];
	}	

	return $str, $hash, $outp;
}

1;
