package Tavola::Generator::Go;

use strict;
use warnings;

use Tavola::Generator::Config;
use vars qw(@ISA);
@ISA = qw(Tavola::Generator::Config);

__PACKAGE__->setup_accessors(
	components => undef,
);

sub config_hash {
	my $self = shift;
	my $config = $self->SUPER::config_hash();
	my $project = $self->{PROJECT};

	$config->{DocumentRoot} = delete $config->{Document_root};
	$config->{ServerURL} = delete $config->{Server_url};
	$config->{UploadDir} = delete $config->{Uploaddir};
	$config->{ConnectArray} = $self->connect_array($project);
	delete $config->{Db};

	$config->{DefaultActions} = {
		GET => $project->{def_action} || 'topics',
		GET_item => 'edit',
		POST => 'insert',
		PUT => 'update',
		DELETE => 'delete',
	};

	for my $tag (keys %{$config->{Chartags} || {}}) {
		my $chartag = $config->{Chartags}->{$tag};
		$chartag->{ContentType} = delete $chartag->{Content_type} if exists $chartag->{Content_type};
	}

	for my $role_name (keys %{$config->{Roles} || {}}) {
		my $role = $config->{Roles}->{$role_name};
		$role->{MaxAge} = delete $role->{Max_age} if exists $role->{Max_age};
		for my $issuer_name (keys %{$role->{Issuers} || {}}) {
			my $issuer = $role->{Issuers}->{$issuer_name};
			$issuer->{ProviderPars} = delete $issuer->{Provider_pars} if exists $issuer->{Provider_pars};
			$issuer->{InPars} = delete $issuer->{In_pars} if exists $issuer->{In_pars};
			$issuer->{OutPars} = delete $issuer->{Out_pars} if exists $issuer->{Out_pars};
			$issuer->{PasswordHash} = delete $issuer->{Password_hash} if exists $issuer->{Password_hash};
		}
	}

	return $config;
}

sub connect_array {
	my ($self, $project) = @_;
	my $family = $self->_db_family($project->{dbtype});
	my $dbname = $project->{dbname} || $project->{database} || '';

	if ($family eq 'sqlite') {
		return [ 'sqlite3', $dbname ];
	}

	my $user = $project->{dbuser} || '';
	my $pass = $project->{dbpass} || '';
	my $host = $project->{host} || '127.0.0.1';

	if ($family eq 'postgresql') {
		my $port = $project->{port} || 5432;
		return [ 'postgres', $user, $pass, $host, "$port", $dbname ];
	}

	my $port = $project->{port} || 3306;
	return [ 'mysql', $user, $pass, $host, "$port", $dbname ];
}

sub module_path {
	my $self = shift;
	return 'example.com/tavola/' . $self->_go_path($self->{PROJECT}->{Project});
}

sub command_dir {
	my $self = shift;
	return $self->_go_path($self->{PROJECT}->{Project});
}

sub go_mod {
	my $self = shift;
	my $module = $self->module_path();
	return qq~module $module

go 1.22

require github.com/guruperl/genelet v0.1.0
~;
}

sub main {
	my $self = shift;
	my $module = $self->module_path();
	return qq~package main

import (
	"log"
	"net/http"

	"$module/internal/app"
)

func main() {
	controller, cleanup, err := app.New(".")
	if err != nil {
		log.Fatal(err)
	}
	if cleanup != nil {
		defer cleanup()
	}

	log.Fatal(http.ListenAndServe(":"+controller.C.ServerPort, controller))
}
~;
}

sub app {
	my $self = shift;
	my $module = $self->module_path();
	my $imports = '';
	my $registrations = '';

	for my $spec (@{$self->_component_specs()}) {
		my $component = $spec->{name};
		my $pkg = $spec->{pkg};
		my $path = $spec->{path};
		$imports .= qq~	$pkg "$module/internal/$path"\n~;
		$registrations .= qq~	controller.ModelFactories["$component"] = func() interface{} { return $pkg.NewModel() }\n~;
		$registrations .= qq~	controller.FilterFactories["$component"] = func() interface{} { return $pkg.NewFilter() }\n~;
	}

	return qq~package app

import (
	"database/sql"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/guruperl/genelet"
	"github.com/go-sql-driver/mysql"
$imports)

var envPattern = regexp.MustCompile(`\\\$\\{([A-Z_][A-Z0-9_]*)\\}`)

func New(root string) (*genelet.Controller, func() error, error) {
	config, err := LoadConfig(root)
	if err != nil {
		return nil, nil, err
	}

	db, err := config.OpenDB()
	if err != nil {
		return nil, nil, err
	}

	return NewController(config, db), db.Close, nil
}

func LoadConfig(root string) (*genelet.Config, error) {
	config, err := genelet.NewConfig(filepath.Join(root, "conf", "config.json"))
	if err != nil {
		return nil, err
	}
	if err := expandConnectArray(config.ConnectArray); err != nil {
		return nil, err
	}
	if err := normalizeConnectArray(config); err != nil {
		return nil, err
	}
	return config, nil
}

func NewController(config *genelet.Config, db *sql.DB) *genelet.Controller {
	controller := genelet.NewController(config, db)
$registrations	return controller
}

func expandConnectArray(values []string) error {
	for i, value := range values {
		expanded, err := expandEnvString(value)
		if err != nil {
			return err
		}
		values[i] = expanded
	}
	return nil
}

func expandEnvString(value string) (string, error) {
	var missing string
	out := envPattern.ReplaceAllStringFunc(value, func(match string) string {
		parts := envPattern.FindStringSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		found, ok := os.LookupEnv(parts[1])
		if !ok {
			missing = parts[1]
			return ""
		}
		return found
	})
	if missing != "" {
		return "", fmt.Errorf("missing required environment variable %s", missing)
	}
	return out, nil
}

func normalizeConnectArray(config *genelet.Config) error {
	if config == nil || len(config.ConnectArray) <= 2 {
		return nil
	}

	driver := genelet.NormalizeDriver(config.ConnectArray[0])
	if len(config.ConnectArray) != 6 {
		return fmt.Errorf("ConnectArray for %s must be [driver,user,password,host,port,database]", driver)
	}
	user := config.ConnectArray[1]
	password := config.ConnectArray[2]
	host := config.ConnectArray[3]
	port := config.ConnectArray[4]
	database := config.ConnectArray[5]

	switch driver {
	case "mysql":
		config.ConnectArray = []string{"mysql", (&mysql.Config{
			User:                 user,
			Passwd:               password,
			Net:                  "tcp",
			Addr:                 net.JoinHostPort(host, port),
			DBName:               database,
			AllowNativePasswords: true,
			ParseTime:            true,
		}).FormatDSN()}
	case "postgres":
		u := url.URL{
			Scheme: "postgres",
			User:   url.UserPassword(user, password),
			Host:   net.JoinHostPort(host, port),
			Path:   "/" + strings.TrimPrefix(database, "/"),
		}
		query := u.Query()
		query.Set("sslmode", "disable")
		u.RawQuery = query.Encode()
		config.ConnectArray = []string{"postgres", u.String()}
	default:
		return fmt.Errorf("unsupported structured ConnectArray driver %s", driver)
	}
	return nil
}
~;
}

sub component_support {
	my $self = shift;
	my $pkg = $self->_component_package();
	return qq~package $pkg

import (
	_ "embed"
	"encoding/json"

	"github.com/guruperl/genelet"
)

//go:embed component.json
var componentJSON []byte

func loadComponent() *genelet.Component {
	var component genelet.Component
	if err := json.Unmarshal(componentJSON, &component); err != nil {
		panic(err)
	}
	applyComponentDefaults(&component)
	if err := genelet.ValidateComponent(&component); err != nil {
		panic(err)
	}
	return &component
}

func applyComponentDefaults(component *genelet.Component) {
	if component.Sortby == "" {
		component.Sortby = "sortby"
	}
	if component.Sortreverse == "" {
		component.Sortreverse = "sortreverse"
	}
	if component.Pageno == "" {
		component.Pageno = "pageno"
	}
	if component.Totalno == "" {
		component.Totalno = "totalno"
	}
	if component.Rowcount == "" {
		component.Rowcount = "rowcount"
	}
	if component.Maxpageno == "" {
		component.Maxpageno = "maxpage"
	}
	if component.Fields == "" {
		component.Fields = "fields"
	}
	if component.Empties == "" {
		component.Empties = "empties"
	}
	if component.TotalForce == 0 {
		component.TotalForce = 1
	}
}
~;
}

sub component_model {
	my $self = shift;
	my $pkg = $self->_component_package();
	return qq~package $pkg

import (
	"net/url"

	"github.com/guruperl/genelet"
)

type Model struct {
	genelet.Model
}

func NewModel() *Model {
	model := &Model{}
	model.Initialize(loadComponent())
	return model
}

func (model *Model) Topics(extra url.Values, nextextra url.Values) error {
	return model.Model.Topics(extra, nextextra)
}

func (model *Model) Edit(extra url.Values, nextextra url.Values) error {
	return model.Model.Edit(extra, nextextra)
}

func (model *Model) Insert(extra url.Values, nextextra url.Values) error {
	return model.Model.Insert(extra, nextextra)
}

func (model *Model) Insupd(extra url.Values, nextextra url.Values) error {
	return model.Model.Insupd(extra, nextextra)
}

func (model *Model) Update(extra url.Values, nextextra url.Values) error {
	return model.Model.Update(extra, nextextra)
}

func (model *Model) Delete(extra url.Values, nextextra url.Values) error {
	return model.Model.Delete(extra, nextextra)
}
~;
}

sub component_filter {
	my $self = shift;
	my $pkg = $self->_component_package();
	return qq~package $pkg

import (
	"net/url"

	"github.com/guruperl/genelet"
)

type Filter struct {
	genelet.Filter
}

func NewFilter() *Filter {
	filter := &Filter{}
	filter.Initialize(loadComponent())
	return filter
}

func (filter *Filter) Before(model *Model, extra url.Values, nextextra url.Values) error {
	return filter.Filter.Before(&model.Model, extra, nextextra)
}

func (filter *Filter) After(model *Model) error {
	return filter.Filter.After(&model.Model)
}
~;
}

sub _component_package {
	my $self = shift;
	return $self->_component_spec($self->{COMPONENT}->{name_component})->{pkg};
}

sub component_dir {
	my ($self, $component) = @_;
	return $self->_component_spec($component)->{path};
}

sub _component_spec {
	my ($self, $component) = @_;
	for my $spec (@{$self->_component_specs()}) {
		return $spec if $spec->{name} eq $component;
	}
	return {
		name => $component,
		path => $self->_go_path($component),
		pkg  => $self->_go_ident($component),
	};
}

sub _component_specs {
	my $self = shift;
	return $self->{_GO_COMPONENT_SPECS} if $self->{_GO_COMPONENT_SPECS};

	my @components = @{$self->{COMPONENTS} || []};
	push @components, $self->{COMPONENT}->{name_component} if !@components && $self->{COMPONENT};
	my (%paths, %pkgs);
	my @specs;
	for my $component (@components) {
		my $path = $self->_unique_go_name($self->_go_path($component), \%paths);
		my $pkg = $self->_unique_go_name($self->_go_ident($component), \%pkgs);
		push @specs, {
			name => $component,
			path => $path,
			pkg  => $pkg,
		};
	}
	$self->{_GO_COMPONENT_SPECS} = \@specs;
	return \@specs;
}

sub _unique_go_name {
	my ($self, $base, $seen) = @_;
	my $name = $base;
	my $index = 2;
	while ($seen->{$name}) {
		$name = $base . '_' . $index++;
	}
	$seen->{$name} = 1;
	return $name;
}

sub _go_path {
	my ($self, $name) = @_;
	my $path = lc($name || 'app');
	$path =~ s/[^a-z0-9_]+/-/g;
	$path =~ s/^-+|-+$//g;
	return $path || 'app';
}

sub _go_ident {
	my ($self, $name) = @_;
	my $ident = lc($name || 'component');
	$ident =~ s/[^a-z0-9_]+/_/g;
	$ident =~ s/^_+|_+$//g;
	$ident = 'component' unless length $ident;
	$ident = "c_$ident" if $ident =~ /^[0-9]/;
	$ident = "component_$ident" if $self->_go_keyword($ident);
	return $ident;
}

sub _go_keyword {
	my ($self, $word) = @_;
	my %keywords = map { $_ => 1 } qw(
		break default func interface select case defer go map struct chan else goto package switch const fallthrough if range type continue for import return var
	);
	return $keywords{$word};
}

1;
