package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRunRefreshesTavolaContractFixtures(t *testing.T) {
	dir := t.TempDir()
	if err := run(dir, "specs/sqlmeta.project.json"); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{
		"testdata/sqlmeta/contracts/manual_pk_fk.project.json",
		"testdata/sqlmeta/contracts/manual_pk_fk.warnings.txt",
		"testdata/sqlmeta/contracts/invalid_overrides.project.json",
		"testdata/sqlmeta/contracts/invalid_overrides.warnings.txt",
		"testdata/sqlmeta/contracts/missing_auth_table.tavola_error.txt",
		"specs/sqlmeta.project.json",
	} {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatalf("missing generated %s: %v", name, err)
		}
		if len(data) == 0 {
			t.Fatalf("%s is empty", name)
		}
	}
	for _, name := range []string{
		"testdata/sqlmeta/contracts/missing_auth_table.project.json",
		"testdata/sqlmeta/contracts/missing_auth_table.warnings.txt",
	} {
		if _, err := os.Stat(filepath.Join(dir, name)); !os.IsNotExist(err) {
			t.Fatalf("unexpected generated %s", name)
		}
	}
}
