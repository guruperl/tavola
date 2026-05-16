package main

import (
	"flag"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/genelet/sqlmeta/xmeta"
	"github.com/guruperl/tavola"
	"google.golang.org/protobuf/encoding/protojson"
)

func TestSQLMetaOptionsRejectsPartialAuth(t *testing.T) {
	_, err := sqlmetaOptions(tavola.GenerateOptions{}, "users", "", "email", "passwd", "", "", "u", false, "")
	if err == nil {
		t.Fatalf("expected partial auth config error")
	}
	if !strings.Contains(err.Error(), "--auth-id") {
		t.Fatalf("expected missing auth id in error, got %v", err)
	}
}

func TestRunSupportsDirectMetaAndExpandedAppDryRun(t *testing.T) {
	scenario, err := xmeta.LoadContractScenario(xmeta.ContractScenarioManualPKFK)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	metaPath := filepath.Join(dir, "meta.json")
	metaJSON, err := protojson.Marshal(scenario.Meta)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(metaPath, metaJSON, 0644); err != nil {
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
	expanded, _, err := xmeta.ExpandRoleScopesWithDiagnostics(scenario.Meta, app)
	if err != nil {
		t.Fatal(err)
	}
	expandedPath := filepath.Join(dir, "expanded.json")
	expandedJSON, err := protojson.Marshal(expanded)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(expandedPath, expandedJSON, 0644); err != nil {
		t.Fatal(err)
	}

	runWithArgs(t, "tavola-generate", "--meta", metaPath, "--project", "SqlmetaApp", "--lang", "go", "--dry-run")
	runWithArgs(t, "tavola-generate", "--meta", metaPath, "--expanded-app", expandedPath, "--project", "SqlmetaApp", "--lang", "php", "--dry-run")
}

func runWithArgs(t *testing.T, args ...string) {
	t.Helper()
	oldArgs := os.Args
	oldFlags := flag.CommandLine
	defer func() {
		os.Args = oldArgs
		flag.CommandLine = oldFlags
	}()
	os.Args = args
	flag.CommandLine = flag.NewFlagSet(args[0], flag.ContinueOnError)
	flag.CommandLine.SetOutput(io.Discard)
	if err := run(); err != nil {
		t.Fatalf("run(%v) failed: %v", args, err)
	}
}
