package Tabilet::Template::Vue;

use strict;
use Tabilet::Template::Base;
use vars qw($AUTOLOAD @ISA);
@ISA = qw(Tabilet::Template::Base);

sub login {
	my $self = shift;
	my $default = shift;

	my $r = $self->{R};

	return qq~<template>
<div>
<h3>{{ names.error_code }}: {{ names.error_string }}</h3>
<FORM id="~.$r.qq~_login" \@submit.prevent="sendit">
<pre>
   Login: <INPUT TYPE="TEXT"     v-model="f0.~.$default->[2].qq~" />
Password: <INPUT TYPE="PASSWORD" v-model="f0.~.$default->[3].qq~" />
<button TYPE="SUBMIT"> Sign In Now </button>
</pre>
</FORM>
</div>
</template>

<script>
module.exports = {
  props: ['names'],
  data: function() {
    return { f0: {} }
  },
  methods: {
    sendit: function(e) {
      this.f0["role"] = "$r";
      this.f0["tag"] = "json";
      \$scope.login('$r', '~.$default->[0].qq~', '~.$default->[1].qq~', this.f0);
    }
  }
}
</script>
~;
}

sub vueCss {
	return qq~
<style>
.modal-mask {
  position: fixed;
  z-index: 9998;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, .5);
  display: table;
  transition: opacity .3s ease;
}

.modal-wrapper {
  display: table-cell;
  vertical-align: middle;
}

.modal-container {
  width: 600px;
  margin: 0px auto;
  padding: 20px 30px;
  background-color: #fff;
  border-radius: 2px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, .33);
  transition: all .3s ease;
  font-family: Helvetica, Arial, sans-serif;
}

.modal-header h3 {
  margin-top: 0;
  color: #42b983;
}

.modal-body {
  margin: 20px 0;
}

.modal-default-button {
  float: right;
}

/*
 * The following styles are auto-applied to elements with
 * transition="modal" when their visibility is toggled
 * by Vue.js.
 *
 * You can easily play with the modal transition by editing
 * these styles.
 */

.modal-enter {
  opacity: 0;
}

.modal-leave-active {
  opacity: 0;
}

.modal-enter .modal-container,
.modal-leave-active .modal-container {
  -webkit-transform: scale(1.1);
  transform: scale(1.1);
}
</style>
~;
}

sub vueTemplate {
	my $self = shift;
	my $form = shift;
	my $pars = $self->{PARS};

	my $str1 = qq~
<template>
  <transition name="modal">
    <div class="modal-mask">
      <div class="modal-wrapper">
        <div class="modal-container">

          <div class="modal-header">
              <button class="modal-default-button" \@click="\$emit('close')">x
              </button>
            <slot name="header"></slot>
          </div>

          <div class="modal-body">
            <slot name="body"></slot>
~;
	my $str2 = qq~
          </div>

          <div class="modal-footer">
            <slot name="footer">
              <button class="modal-default-button" \@click="\$emit('close')"> close
              </button>
            </slot>
          </div>
        </div>
      </div>
    </div>
  </transition>
</template>
~;

	my $str = "";
	if ($form) {
		$str .= qq~
            <form id="$form" \@submit.prevent="sendit">
<pre>
~;
		for my $par (@$pars) {
		$str .= ucfirst($par) . qq~: <INPUT v-model="f0.$par">
~;
		}
		$str .= qq~
</pre>
<button TYPE="SUBMIT"> Submit </button>
            </form>
~;
	} else {
		for my $par (@$pars) {
			$str .= ucfirst($par) . qq~: {{ f0.$par }}
~;
		}
	}

	return $str1 . $str. $str2;
}

sub startnew {
	my $self = shift;
	my ($is_insert) = @_;

	my $r = $self->{R};
	my $c = $self->{C};

	my $str = $self->vueTemplate("$r-$c-insert") . qq~
<script>
  module.exports = {
    name: '$r-$c-startnew',
    data: function() {
        return { f0 : {} }
    },
    methods: {
      sendit: function() {
        \$scope.send('$r', '$c', 'insert', this.f0, {operator:"insert"});
        this.\$emit('close');
      }
    }
  }
</script>
~;
	return $str . vueCss();
}

sub edit {
	my $self = shift;
	my ($is_update) = @_;

	my $r = $self->{R};
	my $c = $self->{C};
	my $uid = $self->{UID};
	my $pars= $self->{PARS};

	my $str = ($is_update) ? $self->vueTemplate("$r-$c-update") :  $self->vueTemplate();
	$str .= qq~
<script>
  module.exports = {
    name: '$r-$c-edit',
    props: ['single', 'id'],
    watch: {
        single: function () {
            this.f0 = this.single
            for (var k in this.f0) {
                if (this.f0[k]===null || this.f0[k]===undefined) {
                    delete this.f0[k];
                }
            }
        }
    },
    data : function() {
        return { f0: {} };
    },
    methods: {
      close() {
        this.\$emit('close');
      },~;
	if ($is_update) {
		$str .= qq~
      sendit: function(e) {
        \$scope.send('$r', '$c', 'update', this.f0, {operator:"update","id_name":"$uid"});
        this.\$emit('close');
      },~;
	}
	$str .= qq~
    },
  }
</script>
~;
	return $str . vueCss();
}

sub topics {
	my $self = shift;
	my ($is_edit, $is_delete, $is_startnew) = @_;

	my $r = $self->{R};
	my $c = $self->{C};
	my $uid = $self->{UID};
	my $pars= $self->{PARS};

	my $str = qq~<template>
<div>
<table>
<thead><tr><th></th>
~;
	for my $par (@$pars) {
		$str .= "<th>".ucfirst($par).qq~</th>
~;
	}
	$str .= qq~<th></th>
</tr>
</thead>
<tbody><tr v-for="item in names.data">
<td>
~;
	if ($is_edit) {
		$str .= qq~
  <$r-$c-edit v-if="showModal && currentID===item.$uid" v-bind:single="currentData" v-bind:id="currentID" \@close="showModal=false">
  </$r-$c-edit>
  <button id="show-modal" \@click="openModal(item.$uid)">{{ item.$uid }}</button>
~;
	}
	$str .= qq~</td>
~;
	for my $par (@$pars) {
		$str .= qq~<td>{{ item.$par }}</td>
~;
	}
	if ($is_delete) {
		$str .= qq~<td><button \@click="deleteItem(item.$uid)">Delete</button></td>
~;
	} else {
		$str .= qq~<td></td>
~;
	}
	$str .= qq~</tr>
</tbody>
</table>
~;
	if ($is_startnew) {
		$str .= qq~<p>
<$r-$c-startnew v-if="newModal" \@close="newModal=false">
</$r-$c-startnew>
<button id="new-modal" \@click="newModal=true">Add New</button>
</p>
~;
	}
	$str .= qq~</div>
</template>

<script>
module.exports = {
  name: '$r-$c-topics',~;
	my @opens = ();
	if ($is_edit) {
		push @opens, qq~    '$r-$c-edit': httpVueLoader('./edit.vue')~;
	}
	if ($is_startnew) {
		push @opens, qq~    '$r-$c-startnew': httpVueLoader('./startnew.vue')~;
	}
	if (scalar(@opens) > 0) {
		$str .= qq~
  components: {
~ . join(",\n", @opens) . qq~
  },~;
	}
	$str .= qq~
  props: ['names'],
  data: function() {
    return {
        newModal: false,
        showModal: false,
        currentID: 0,
        currentData: null,
    };
  }~;

	my @funcs = ();
	if ($is_edit) {
		push @funcs, qq~    openModal: function(id) {
      that = this;
      var mylanding = function(x) {
        that.currentData = JSON.parse(JSON.stringify(x.data[0]));
      };
      \$scope.ajaxPage("$r", "$c", {action:"edit", $uid:id}, "GET", mylanding);
      this.currentID = id;
      this.showModal = true;
    }~;
	}
	if ($is_delete) {
		push @funcs, qq~    deleteItem: function(id) {
      if (confirm("Are you sure to delete this ID: " + id + "?")) {
        \$scope.ajaxPage("$r", "$c", {action:"delete", $uid:id}, "GET", {operator:"delete", "id_name":"$uid"});
      }
    }~;
	}
	
	if (scalar(@funcs) > 0) {
		$str .= qq~,
  methods: {
~ . join(",\n", @funcs) . qq~
  }~;
	}
	$str .= qq~
}
</script>
~;
	return $str;
}

1;
