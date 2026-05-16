package tavola

import (
	"strconv"
	"strings"
)

func emitPHP(a *Archive, model *generationModel) {
	project := ucfirst(model.Project.Project)
	a.AddString("composer.json", phpComposer(project, model.Components))
	a.AddString("www/app.php", phpApp(project))
	a.AddString("src/Application.php", phpApplication(project, model.Components))
	a.AddString("src/Beacon.php", phpBeacon(project))
	a.AddString("src/Filter.php", phpProjectFilter(project))
	a.AddString("src/Model.php", phpProjectModel(project))
	for _, comp := range model.Components {
		cap := ucfirst(comp.Name)
		a.AddString("src/"+comp.Name+"/component.json", comp.ComponentJS)
		a.AddString("src/"+comp.Name+"/Beacon.php", phpComponentBeacon(project, cap, comp.Name))
		a.AddString("src/"+comp.Name+"/Filter.php", phpComponentFilter(project, cap))
		a.AddString("src/"+comp.Name+"/Model.php", phpComponentModel(project, cap))
	}
}

func phpComposer(project string, comps []componentRow) string {
	autoload := map[string]string{project + "\\": "src/"}
	for _, comp := range comps {
		autoload[project+"\\"+ucfirst(comp.Name)+"\\"] = "src/" + comp.Name + "/"
	}
	return mustJSON(map[string]any{
		"name":        "genelet/project-php",
		"description": "Sample Application of Genelet Framework",
		"license":     "LGPL-2.1-only",
		"type":        "project",
		"require":     map[string]string{"genelet/php": "^1.3.2"},
		"autoload":    map[string]any{"psr-4": autoload},
	})
}

func phpApplication(project string, comps []componentRow) string {
	componentConst := "[]"
	if len(comps) > 0 {
		values := make([]string, 0, len(comps))
		for _, comp := range comps {
			values = append(values, strconv.Quote(comp.Name))
		}
		componentConst = "[" + strings.Join(values, ", ") + "]"
	}
	return `<?php
declare(strict_types=1);

namespace ` + project + `;

use Genelet\Controller;
use Genelet\Logger;
use PDO;
use RuntimeException;

final class Application
{
    private const COMPONENTS = ` + componentConst + `;

    public static function config(): object
    {
        $root = dirname(__DIR__);
        $config = json_decode(file_get_contents($root . "/conf/config.json"));
        $config = self::expandEnv($config);

        $config->{"Document_root"} = self::path($root, $config->{"Document_root"});
        $config->{"Template"} = self::path($root, $config->{"Template"});
        $config->{"Uploaddir"} = self::path($root, $config->{"Uploaddir"});
        $config->{"Log"}->{"Filename"} = self::path($root, $config->{"Log"}->{"Filename"});

        self::ensureDir($config->{"Uploaddir"});
        self::ensureDir(dirname($config->{"Log"}->{"Filename"}));

        $dsn = getenv("TAVOLA_DB_DSN");
        if ($dsn !== false && $dsn !== "") {
            $config->{"Db"} = [
                $dsn,
                getenv("TAVOLA_DB_USER") ?: "",
                getenv("TAVOLA_DB_PASSWORD") ?: "",
            ];
        }

        return $config;
    }

    public static function pdo(object $config): PDO
    {
        return new PDO(...$config->{"Db"});
    }

    public static function logger(object $config): Logger
    {
        return new Logger($config->{"Log"}->{"Filename"}, $config->{"Log"}->{"Level"});
    }

    public static function components(PDO $pdo): array
    {
        $jsons = [];
        $storage = [];
        foreach (self::COMPONENTS as $item) {
            $jsons[$item] = json_decode(file_get_contents(__DIR__ . "/$item/component.json"));
            $class = "\\` + project + `\\" . ucfirst($item) . "\\Model";
            $storage[$item] = new $class($pdo, $jsons[$item]);
        }

        return [$jsons, $storage];
    }

    public static function controller(object $config = null): Controller
    {
        $config = $config ?? self::config();
        $pdo = self::pdo($config);
        [$jsons, $storage] = self::components($pdo);

        return new Controller($config, $pdo, $jsons, $storage, self::logger($config));
    }

    public static function render(object $response, object $config): ?array
    {
        if ($response->is_json) {
            return null;
        }

        $paths = [$config->{"Template"} . "/" . $response->role];
        if (!empty($response->component)) {
            $paths[] = $config->{"Template"} . "/" . $response->role . "/" . $response->component;
        }

        $twig = new \Twig\Environment(new \Twig\Loader\FilesystemLoader($paths));
        return [$twig, "render"];
    }

    private static function path(string $root, string $path): string
    {
        if ($path !== "" && ($path[0] === "/" || preg_match('/^[A-Za-z]:[\\\\\/]/', $path) === 1)) {
            return $path;
        }

        return $root . "/" . $path;
    }

    private static function ensureDir(string $path): void
    {
        if (!is_dir($path)) {
            mkdir($path, 0777, true);
        }
    }

    private static function expandEnv($value)
    {
        if (is_object($value)) {
            foreach (get_object_vars($value) as $key => $item) {
                $value->{$key} = self::expandEnv($item);
            }
            return $value;
        }
        if (is_array($value)) {
            foreach ($value as $key => $item) {
                $value[$key] = self::expandEnv($item);
            }
            return $value;
        }
        if (is_string($value) && preg_match('/^\$\{([A-Z_][A-Z0-9_]*)\}$/', $value, $matches) === 1) {
            $env = getenv($matches[1]);
            if ($env === false) {
                throw new RuntimeException("Missing required environment variable " . $matches[1]);
            }
            return $env;
        }

        return $value;
    }
}
`
}

func phpApp(project string) string {
	return `<?php
declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

$c = \` + project + `\Application::config();
$resp = \` + project + `\Application::controller($c)->Run();
echo $resp->report(\` + project + `\Application::render($resp, $c));
`
}

func phpBeacon(project string) string {
	return `<?php
declare(strict_types=1);

namespace ` + project + `;

class Beacon extends \Genelet\Beacon
{
    public function __construct(string $role) {
        $ip  = "192.168.1.2";
        $tag = "json";
        $headers = ['Content-Type'=>"application/x-www-form-urlencoded", 'Cookie' => array("go_probe"=>"/")];
        $c = Application::config();
        $pdo = Application::pdo($c);
        [$jsons, $storage] = Application::components($pdo);
        parent::__construct($c, $pdo, $jsons, $storage, Application::logger($c), $role, $tag, $ip, $headers);
    }
}
`
}

func phpProjectFilter(project string) string {
	return `<?php
declare(strict_types=1);

namespace ` + project + `;
use Genelet;

class Filter extends \Genelet\Filter
{
public function Preset() : ?\Genelet\Gerror  {
  $err = parent::Preset();
  if ($err != null) { return $err; }
  $ARGS =& $_REQUEST;
  $action = $this->Action;
  if ($action == 'topics') {
    if (empty($ARGS["rowcount"])) {$ARGS["rowcount"] = 100;}
    if (empty($ARGS["pageno"])) {$ARGS["pageno"] = 1;}
  }
  if ($action=='insert' || $action=='activate') {
    $ARGS["created"] = date('Y-m-d H:i:s', $_SERVER['REQUEST_TIME']);
    $ARGS["ip"] = self::get_lb_ip();
  }
  return null;
}

public function Before(object &$model, array &$extra, array &$nextextra, array &$onceextra=null) : ?\Genelet\Gerror {
  $err = parent::Before($model, $extra, $nextextra, $onceextra);
  if ($err != null) { return $err; }
  return null;
}

public function After(object $model, array $onceextra=null) : ?\Genelet\Gerror {
  $err = parent::After($model, $onceextra);
  if ($err != null) { return $err; }
  return null;
}

public static function get_lb_ip() : string {
    if (isset($_SERVER["REMOTE_ADDR"]) && (substr($_SERVER["REMOTE_ADDR"],0,8) == "192.168." || substr($_SERVER["REMOTE_ADDR"],0,3) == "10.") && isset($_SERVER["HTTP_X_FORWARDED_FOR"])) {
        if (preg_match_all("/(\d+\.\d+\.\d+\.\d+)$/", $_SERVER["HTTP_X_FORWARDED_FOR"], $matches_out)) {
            return $matches_out[0][0];
        }
    }
    return $_SERVER["REMOTE_ADDR"] ?? "127.0.0.1";
}
}
`
}

func phpProjectModel(project string) string {
	return "<?php\ndeclare(strict_types=1);\n\nnamespace " + project + ";\nuse Genelet;\n\nclass Model extends \\Genelet\\Model\n{\n};\n"
}

func phpComponentBeacon(project, comp, component string) string {
	return `<?php
declare(strict_types=1);

namespace ` + project + `\` + comp + `;
use ` + project + `;

class Beacon extends \` + project + `\Beacon
{
    public function GET(string $query=null) {
        return parent::get_mock("` + component + `", $query);
    }

    public function POST(array $data) {
        return parent::post_mock("` + component + `", $data);
    }
}
`
}

func phpComponentFilter(project, comp string) string {
	return `<?php
declare(strict_types=1);

namespace ` + project + `\` + comp + `;
use ` + project + `;

class Filter extends \` + project + `\Filter
{
public function Preset() : ?\Genelet\Gerror  {
  $err = parent::Preset();
  if ($err !== null) { return $err; }
  return null;
}

public function Before(object &$model, array &$extra, array &$nextextra, array &$onceextra=null)  : ?\Genelet\Gerror {
  $err = parent::Before($model, $extra, $nextextra, $onceextra);
  if ($err !== null) { return $err; }
  return null;
}

public function After(object $model, array $onceextra=null) : ?\Genelet\Gerror {
  $err = parent::After($model, $onceextra);
  if ($err !== null) { return $err; }
  return null;
}
}
`
}

func phpComponentModel(project, comp string) string {
	return "<?php\ndeclare(strict_types=1);\n\nnamespace " + project + "\\" + comp + ";\nuse " + project + ";\n\nclass Model extends \\" + project + "\\Model\n{\n};\n"
}
