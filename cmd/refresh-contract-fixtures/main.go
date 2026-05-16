package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/genelet/sqlmeta/xmeta"
	"github.com/guruperl/tavola"
)

func main() {
	var root, specOut string
	flag.StringVar(&root, "root", ".", "Tavola repository root")
	flag.StringVar(&specOut, "spec-out", "specs/sqlmeta.project.json", "optional Tavola project JSON path to sync from manual_pk_fk; relative to --root unless absolute")
	flag.Parse()

	if err := run(root, specOut); err != nil {
		fmt.Fprintln(os.Stderr, "refresh-contract-fixtures:", err)
		os.Exit(1)
	}
}

func run(root, specOut string) error {
	if err := writeSuccessScenario(root, xmeta.ContractScenarioManualPKFK, specOut); err != nil {
		return err
	}
	if err := writeSuccessScenario(root, xmeta.ContractScenarioInvalidOverrides, ""); err != nil {
		return err
	}
	if err := writeMissingAuthScenario(root); err != nil {
		return err
	}
	return nil
}

func writeSuccessScenario(root, name, specOut string) error {
	scenario, err := xmeta.LoadContractScenario(name)
	if err != nil {
		return err
	}
	app, err := xmeta.BuildDefaultAppSpec(scenario.Meta, xmeta.AppSpecOptions{
		Name:            scenario.AppName,
		Auth:            scenario.Auth,
		RoleName:        scenario.RoleName,
		SchemaOverrides: scenario.SchemaOverrides,
	})
	if err != nil {
		return err
	}
	expanded, diagnostics, err := xmeta.ExpandRoleScopesWithDiagnostics(scenario.Meta, app)
	if err != nil {
		return err
	}
	spec, err := tavola.BuildTavolaSpecFromExpandedApp(scenario.Meta, expanded, diagnostics, tavolaOptions())
	if err != nil {
		return err
	}

	if err := writeJSON(filepath.Join(contractDir(root), name+".project.json"), spec); err != nil {
		return err
	}
	if err := writeWarnings(filepath.Join(contractDir(root), name+".warnings.txt"), specWarnings(spec)); err != nil {
		return err
	}
	if specOut != "" {
		if err := writeJSON(resolveRootPath(root, specOut), spec); err != nil {
			return err
		}
	}
	return nil
}

func writeMissingAuthScenario(root string) error {
	scenario, err := xmeta.LoadContractScenario(xmeta.ContractScenarioMissingAuthTable)
	if err != nil {
		return err
	}
	_, err = tavola.BuildTavolaSpecFromSQLMeta(scenario.Meta, tavola.SQLMetaGenerateOptions{
		GenerateOptions: tavolaOptions(),
		AppSpec: xmeta.AppSpecOptions{
			Name:            scenario.AppName,
			Auth:            scenario.Auth,
			RoleName:        scenario.RoleName,
			SchemaOverrides: scenario.SchemaOverrides,
		},
	})
	if err == nil {
		return fmt.Errorf("%s Tavola build succeeded unexpectedly", scenario.Name)
	}
	if err := writeText(filepath.Join(contractDir(root), scenario.Name+".tavola_error.txt"), err.Error()); err != nil {
		return err
	}
	for _, stale := range []string{
		scenario.Name + ".project.json",
		scenario.Name + ".warnings.txt",
	} {
		if err := os.Remove(filepath.Join(contractDir(root), stale)); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func tavolaOptions() tavola.GenerateOptions {
	return tavola.GenerateOptions{
		Project:            "SqlmetaApp",
		Script:             "/sqlmeta/app.php",
		PublicRole:         "p",
		OwnerLogin:         "local",
		OwnerEmail:         "local@example.test",
		OwnerTypeID:        1,
		DatasourceType:     "SQLite",
		DatasourceNickname: "sqlmeta",
		DatasourceDatabase: "app.sqlite",
		DatasourcePath:     "data/sqlmeta.sqlite",
	}
}

func contractDir(root string) string {
	return filepath.Join(root, "testdata/sqlmeta/contracts")
}

func resolveRootPath(root, path string) string {
	if filepath.IsAbs(path) {
		return path
	}
	return filepath.Join(root, path)
}

func specWarnings(spec *tavola.Spec) []string {
	if spec == nil || spec.Introspection == nil {
		return nil
	}
	return spec.Introspection.Warnings
}

func writeJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	return writeFile(path, append(data, '\n'))
}

func writeWarnings(path string, warnings []string) error {
	return writeFile(path, []byte(strings.Join(warnings, "\n")+"\n"))
}

func writeText(path string, text string) error {
	return writeFile(path, []byte(text+"\n"))
}

func writeFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}
