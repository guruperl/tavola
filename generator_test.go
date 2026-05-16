package tavola

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/genelet/sqlmeta/xmeta"
)

func TestGenerateFromSQLMetaDirectContractScenario(t *testing.T) {
	scenario, err := xmeta.LoadContractScenario(xmeta.ContractScenarioManualPKFK)
	if err != nil {
		t.Fatal(err)
	}
	for _, lang := range []Language{LanguagePHP, LanguagePerl, LanguageGo} {
		t.Run(string(lang), func(t *testing.T) {
			archive, err := GenerateFromSQLMeta(scenario.Meta, SQLMetaGenerateOptions{
				GenerateOptions: GenerateOptions{
					Language:           lang,
					Project:            "SqlmetaApp",
					Script:             "/sqlmeta/app.php",
					PublicRole:         "p",
					DatasourceType:     "SQLite",
					DatasourceNickname: "sqlmeta",
					DatasourceDatabase: "app.sqlite",
					DatasourcePath:     "data/sqlmeta.sqlite",
					Deterministic:      true,
				},
				AppSpec: xmeta.AppSpecOptions{
					Name:            scenario.AppName,
					Auth:            scenario.Auth,
					RoleName:        scenario.RoleName,
					SchemaOverrides: scenario.SchemaOverrides,
				},
			})
			if err != nil {
				t.Fatal(err)
			}
			files := filesByPath(archive)
			if files["conf/init.sql"] == "" || files["api.json"] == "" || files["openapi.json"] == "" {
				t.Fatalf("missing common archive files: %#v", files)
			}
			var api map[string]any
			if err := json.Unmarshal([]byte(files["api.json"]), &api); err != nil {
				t.Fatal(err)
			}
			if api["format"] != "tavola-api-manifest" {
				t.Fatalf("unexpected api format %v", api["format"])
			}
			introspection, ok := api["introspection"].(map[string]any)
			if !ok {
				t.Fatalf("api manifest missing sqlmeta introspection metadata")
			}
			if introspection["source"] != "sqlmeta" {
				t.Fatalf("unexpected introspection source %v", introspection["source"])
			}
			if got := len(introspection["warnings"].([]any)); got == 0 {
				t.Fatalf("expected introspection warnings")
			}
			details := introspection["warning_details"].([]any)
			if len(details) == 0 {
				t.Fatalf("expected warning details")
			}
			if code := details[0].(map[string]any)["code"]; code == "" || code == xmeta.DiagnosticUnknown {
				t.Fatalf("expected stable diagnostic code, got %v", code)
			}
			var openapi map[string]any
			if err := json.Unmarshal([]byte(files["openapi.json"]), &openapi); err != nil {
				t.Fatal(err)
			}
			if _, ok := openapi["x-tavola-introspection"]; !ok {
				t.Fatalf("openapi missing introspection extension")
			}
			if !containsText(files["docs/api.md"], "## Introspection Warnings") {
				t.Fatalf("api docs missing introspection warnings")
			}
			switch lang {
			case LanguagePHP:
				if files["src/posts/component.json"] == "" || files["www/app.php"] == "" {
					t.Fatalf("missing php files")
				}
			case LanguagePerl:
				if files["lib/SqlmetaApp/Posts/component.json"] == "" || files["script/app"] == "" {
					t.Fatalf("missing perl files")
				}
			case LanguageGo:
				if files["internal/posts/component.json"] == "" || files["internal/app/app.go"] == "" {
					t.Fatalf("missing go files")
				}
			}
		})
	}
}

func TestGenerateFromExpandedAppWithDiagnosticsPreservesCodes(t *testing.T) {
	scenario, err := xmeta.LoadContractScenario(xmeta.ContractScenarioManualPKFK)
	if err != nil {
		t.Fatal(err)
	}
	app, err := xmeta.BuildDefaultAppSpec(scenario.Meta, xmeta.AppSpecOptions{
		Name:            scenario.AppName,
		Auth:            scenario.Auth,
		RoleName:        scenario.RoleName,
		SchemaOverrides: scenario.SchemaOverrides,
	})
	if err != nil {
		t.Fatal(err)
	}
	expanded, diagnostics, err := xmeta.ExpandRoleScopesWithDiagnostics(scenario.Meta, app)
	if err != nil {
		t.Fatal(err)
	}
	archive, err := GenerateFromExpandedAppWithDiagnostics(scenario.Meta, expanded, diagnostics, GenerateOptions{
		Language:           LanguageGo,
		Project:            "SqlmetaApp",
		PublicRole:         "p",
		DatasourceType:     "SQLite",
		DatasourceDatabase: "app.sqlite",
		Deterministic:      true,
	})
	if err != nil {
		t.Fatal(err)
	}
	api := filesByPath(archive)["api.json"]
	if !containsText(api, `"warning_details"`) {
		t.Fatalf("api manifest missing warning details:\n%s", api)
	}
	if containsText(api, `"code": "unknown"`) {
		t.Fatalf("api manifest lost diagnostic codes:\n%s", api)
	}
}

func TestGenerateFromTavolaSpecCompatibility(t *testing.T) {
	for _, name := range []string{
		"project.template.json",
		"go-smoke.project.json",
		"supportdesk.project.json",
		"sqlmeta.project.json",
	} {
		t.Run(name, func(t *testing.T) {
			data, err := os.ReadFile(filepath.Join("specs", name))
			if err != nil {
				t.Fatal(err)
			}
			spec, err := LoadTavolaSpecJSON(data)
			if err != nil {
				t.Fatal(err)
			}
			archive, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: LanguageGo, Deterministic: true})
			if err != nil {
				t.Fatal(err)
			}
			files := filesByPath(archive)
			for _, path := range []string{"go.mod", "conf/config.json", "api.json", "openapi.json"} {
				if files[path] == "" {
					t.Fatalf("missing %s", path)
				}
			}
		})
	}
}

func TestTavolaSpecFileBackedInputs(t *testing.T) {
	spec, err := LoadTavolaSpecFile(filepath.Join("specs", "jenny.project.json"))
	if err != nil {
		t.Fatal(err)
	}
	archive, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: LanguagePHP, Deterministic: true})
	if err != nil {
		t.Fatal(err)
	}
	files := filesByPath(archive)
	if got := files["conf/init.sql"]; !containsText(got, "CREATE TABLE `poll_question`") {
		t.Fatalf("init.sql did not include statementFile DDL:\n%s", got)
	}
	if got := files["src/question/component.json"]; !containsText(got, `"current_table"`) {
		t.Fatalf("componentJsonFile was not copied: %s", got)
	}
}

func TestGeneratedPHPAndPerlAreRoutedApps(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("specs", "project.template.json"))
	if err != nil {
		t.Fatal(err)
	}
	spec, err := LoadTavolaSpecJSON(data)
	if err != nil {
		t.Fatal(err)
	}
	for _, lang := range []Language{LanguagePHP, LanguagePerl} {
		archive, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: lang, Deterministic: true})
		if err != nil {
			t.Fatal(err)
		}
		files := filesByPath(archive)
		if lang == LanguagePHP && !containsText(files["src/Application.php"], "new Controller(") {
			t.Fatalf("PHP Application does not construct Genelet Controller")
		}
		if lang == LanguagePerl && !containsText(files["script/app"], "Genelet::Dispatch::run") {
			t.Fatalf("Perl app does not dispatch through Genelet")
		}
	}
}

func TestRejectsUnsafeArchiveNames(t *testing.T) {
	spec := minimalSpec()
	spec.Components[0].Name = "../escape"
	if _, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: LanguagePHP}); err == nil {
		t.Fatalf("expected unsafe component name to be rejected")
	}
}

func TestGoComponentNameCollisionsAreUnique(t *testing.T) {
	spec := minimalSpec()
	spec.Schema.Tables = append(spec.Schema.Tables, Table{
		Name: "items2", PrimaryKey: "id", Statement: "CREATE TABLE items2 (id INTEGER PRIMARY KEY)",
		Insert: []string{"id"}, Edit: []string{"id"}, Update: []string{"id"}, Topics: []string{"id"},
	})
	spec.Components = []Component{
		{Name: "foo-bar", Description: "one", Table: "items", Public: []string{"topics"}},
		{Name: "foo_bar", Description: "two", Table: "items2", Public: []string{"topics"}},
	}
	archive, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: LanguageGo, Deterministic: true})
	if err != nil {
		t.Fatal(err)
	}
	files := filesByPath(archive)
	if files["internal/foo-bar/component.json"] == "" {
		t.Fatalf("missing first colliding component dir")
	}
	if files["internal/foo_bar/component.json"] == "" {
		t.Fatalf("missing second colliding component dir")
	}
	if !containsText(files["internal/app/app.go"], `foo_bar_2 "example.com/tavola/collision/internal/foo_bar"`) {
		t.Fatalf("expected unique package alias in app.go:\n%s", files["internal/app/app.go"])
	}
}

func minimalSpec() *Spec {
	return &Spec{
		Version:    1,
		Owner:      Owner{Login: "local", Email: "local@example.test", TypeID: 1},
		Project:    Project{Name: "Collision", Script: "/app.php", PublicRole: "p", Default: ProjectDefault{Component: "foo-bar", Action: "topics"}},
		Datasource: Datasource{Type: "SQLite", Nickname: "test", Database: "test.sqlite"},
		Schema: Schema{Tables: []Table{{
			Name: "items", PrimaryKey: "id", Statement: "CREATE TABLE items (id INTEGER PRIMARY KEY)",
			Insert: []string{"id"}, Edit: []string{"id"}, Update: []string{"id"}, Topics: []string{"id"},
		}}},
		Roles:      []Role{},
		Components: []Component{{Name: "foo-bar", Description: "items", Table: "items", Public: []string{"topics"}}},
		Overlays:   map[string]any{},
	}
}

func containsText(value, want string) bool {
	return strings.Contains(value, want)
}

func filesByPath(archive *Archive) map[string]string {
	out := map[string]string{}
	for _, file := range archive.Files() {
		out[file.Path] = string(file.Data)
	}
	return out
}
