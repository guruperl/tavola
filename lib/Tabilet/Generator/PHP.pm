package Tabilet::Generator::PHP;

use strict;
use Tabilet::Generator::Config;
use vars qw($AUTOLOAD @ISA);
@ISA = qw(Tabilet::Generator::Config);

__PACKAGE__->setup_accessors(
	components => undef, # component names only
);

sub project_filter {
	my $self = shift;
	my $project = ucfirst $self->{PROJECT}->{Project};

	return qq~<?php
declare (strict_types = 1);

namespace $project;
use Genelet;

class Filter extends \\Genelet\\Filter
{

public function Preset() : ?\\Genelet\\Gerror  {
  \$err = parent::Preset();
  if (\$err != null) { return \$err; }

  \$ARGS =& \$_REQUEST;
  \$role = \$this->Role_name;
  \$action = \$this->Action;
  \$obj = \$this->Component;

  if (\$action == 'topics') {
    if (empty(\$ARGS["rowcount"])) {\$ARGS["rowcount"] = 100;}
    if (empty(\$ARGS["pageno"])) {\$ARGS["pageno"]   = 1;}
  }

  if (\$action=='insert' || \$action=='activate') {
    \$ARGS["created"] = date('Y-m-d H:i:s', \$_SERVER['REQUEST_TIME']);
    \$ARGS["ip"] = self::get_lb_ip();
  }

  return null;
}

public function Before(object &\$model, array &\$extra, array &\$nextextra, array &\$onceextra=null) : ?\\Genelet\\Gerror {
  \$err = parent::Before(\$model, \$extra, \$nextextra, \$onceextra);
  if (\$err != null) { return \$err; }

  \$ARGS =& \$_REQUEST;
  \$role = \$this->Role_name;
  \$action = \$this->Action;
  \$obj = \$this->Component;

  return null;
}

public function After(object \$model, array \$onceextra=null) : ?\\Genelet\\Gerror {
  \$err = parent::After(\$model, \$onceextra);
  if (\$err != null) { return \$err; }

  \$ARGS =& \$_REQUEST;
  \$role = \$this->Role_name;
  \$action = \$this->Action;
  \$obj = \$this->Component;

  return null;
}

public static function get_lb_ip() : string {
    if ( (substr(\$_SERVER["REMOTE_ADDR"],0,8) == "192.168."
            || substr(\$_SERVER["REMOTE_ADDR"],0,3) == "10.")
        && isset(\$_SERVER["HTTP_X_FORWARDED_FOR"])) {
        if (preg_match_all("/(\\d+\\.\\d+\\.\\d+\\.\\d+)\$/",
            \$_SERVER["HTTP_X_FORWARDED_FOR"], \$matches_out)) {
            return \$matches_out[0];
        }
    }
    return \$_SERVER["REMOTE_ADDR"];
}

}
~;
}

sub project_model {
	my $self = shift;
    my $project = ucfirst $self->{PROJECT}->{Project};

    return qq~<?php
declare (strict_types = 1);

namespace $project;
use Genelet;

class Model extends \\Genelet\\Model
{
};
~;
}

sub composer {
	my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};

	my $str = qq~{
    "name": "genelet/project-php",
    "description": "Sample Application of Genelet Framework",
    "type": "project",
    "authors": [
        {
            "name": "Greetingland, LLC",
            "email": "genelet\@gmail.com"
        }
    ],
    "require": {
        "genelet/php": "^1.3.0"
    },
    "autoload": {
        "psr-4" : {
            "$project\\\\" : "src"~;
	for my $item (@{$self->{COMPONENTS}}) {
		$str .= qq~,
			"$project\\\\~.ucfirst($item).qq~\\\\" : "src/$item"~;
	}
	return $str . qq~
		}
	}
}
~;
}	

sub project_beacon {
	my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};
	my $str = join('","', @{$self->{COMPONENTS}});	

	return qq~<?php
declare (strict_types = 1);

namespace $project;
use PDO;

use Genelet;

class Beacon extends \\Genelet\\Beacon
{
    public function __construct(string \$role) {
        \$ip  = "192.168.1.2";
        \$tag = "json";
        \$headers = ['Content-Type'=>"application/x-www-form-urlencoded", 'Cookie' => array("go_probe"=>"/")];
        \$c = json_decode(file_get_contents(__DIR__."/../conf/config.json"));
        \$logger = new \\Genelet\\Logger(\$c->{"Log"}->{"Filename"}, \$c->{"Log"}->{"Level"});
        \$pdo = new \\PDO(...\$c->{"Db"});
        \$jsons = array();
        \$storage = array();
        foreach (["~.$str.qq~"] as \$item) {
            \$jsons[\$item] = json_decode(file_get_contents(__DIR__."/\$item/component.json"));
            \$class = '\\\\'."$project".'\\\\'.ucfirst(\$item).'\\\\'."Model";
            \$storage[\$item]  = new \$class(\$pdo, \$jsons[\$item]);
        }
        parent::__construct(\$c, \$pdo, \$jsons, \$storage, \$logger, \$role, \$tag, \$ip, \$headers);
    }
}
~
}

sub app {
	my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};
	my $str = join('","', @{$self->{COMPONENTS}});	

	return qq~<?php
declare (strict_types = 1);

require __DIR__ . '/../vendor/autoload.php';

\$c = json_decode(file_get_contents( __DIR__ . "/../conf/config.json"));
\$pdo = new PDO(...\$c->{"Db"});

\$jsons = array();
\$storage = array();
foreach (["~.$str.qq~"] as \$item) {
    \$jsons[\$item] = json_decode(file_get_contents(__DIR__ . "/../src/\$item/component.json"));
    \$class = '\\\\'."$project".'\\\\'.ucfirst(\$item).'\\\\'."Model";
    \$storage[\$item]  = new \$class(\$pdo, \$jsons[\$item]);
}
\$logger = new \\Genelet\\Logger(\$c->{"Log"}->{"Filename"}, \$c->{"Log"}->{"Level"});
\$controller = new \\Genelet\\Controller(\$c, \$pdo, \$jsons, \$storage, \$logger);
\$resp = \$controller->Run();

if (\$resp->code !== 200 || \$resp->is_json) {
    echo \$resp->report();
} else {
    \$loader = (\$resp->page_type=="error" || \$resp->page_type=="login") ?
    new \\Twig\\Loader\\FilesystemLoader( \$c->{"Template"}."/".\$resp->role) :
    new \\Twig\\Loader\\FilesystemLoader([\$c->{"Template"}."/".\$resp->role, \$c->{"Template"}."/".\$resp->role ."/". \$resp->component]);
    \$twig = new \\Twig\\Environment(\$loader, ['debug' => true]);
	\$twig->addExtension(new \\Twig\\Extension\\DebugExtension());
    echo \$resp->report(Array(\$twig, "render"));
}

?>
~
}

sub filter {
    my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};
	my $comp    = ucfirst $self->{COMPONENT}->{name_component};

	return qq~<?php
declare (strict_types = 1);

namespace $project\\$comp;
use $project;

class Filter extends \\$project\\Filter
{

public function Preset() : ?\\Genelet\\Gerror  {
  \$err = parent::Preset();
  if (\$err !== null) { return \$err; }

  \$ARGS =& \$_REQUEST;
  \$role = \$this->Role_name;
  \$action = \$this->Action;
  \$obj = \$this->Component;

  return null;
}

public function Before(object &\$model, array &\$extra, array &\$nextextra, array &\$onceextra=null)  : ?\\Genelet\\Gerror {
  \$err = parent::Before(\$model, \$extra, \$nextextra, \$onceextra);
  if (\$err !== null) { return \$err; }

  \$ARGS =& \$model->ARGS;
  \$role = \$this->Role_name;
  \$action = \$this->Action;
  \$obj = \$this->Component;

  return null;
}

public function After(object \$model, array \$onceextra=null) : ?\\Genelet\\Gerror {
  \$err = parent::After(\$model, \$onceextra);
  if (\$err !== null) { return \$err; }

  \$ARGS =& \$model->ARGS;
  \$role = \$this->Role_name;
  \$action = \$this->Action;
  \$obj = \$this->Component;

  return null;
}

}
~;
}

sub beacon {
    my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};
	my $comp    = ucfirst $self->{COMPONENT}->{name_component};

    return qq~<?php
declare (strict_types = 1);

namespace $project\\$comp;
use $project;

class Beacon extends \\$project\\Beacon
{
    public function GET(string \$query=null) {
        return parent::get_mock("$comp", \$query);
    }

    public function POST(array \$data) {
        return parent::post_mock("$comp", \$data);
    }
}
~;
}

sub model {
    my $self = shift;

    my $project = ucfirst $self->{PROJECT}->{Project};
	my $comp    = ucfirst $self->{COMPONENT}->{name_component};

    return qq~<?php
declare (strict_types = 1);

namespace $project\\$comp;
use $project;

class Model extends \\$project\\Model
{
};
~;
}

1;
