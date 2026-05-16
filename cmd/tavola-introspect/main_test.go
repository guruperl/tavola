package main

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/genelet/sqlmeta/xmeta"
	"github.com/guruperl/tavola"
)

func TestRunSQLiteWritesTavolaSpec(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "app.db")
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`CREATE TABLE users (id integer primary key, email text not null unique, passwd text not null)`); err != nil {
		db.Close()
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}

	out := filepath.Join(dir, "spec.json")
	err = run("sqlite3", dbPath, "app", nil, "SmokeApp", out, false, tavola.SQLMetaGenerateOptions{
		GenerateOptions: tavola.GenerateOptions{
			Project:            "SmokeApp",
			OwnerLogin:         "local",
			OwnerEmail:         "local@example.test",
			DatasourceDatabase: "app",
			DatasourcePath:     dbPath,
		},
		AppSpec: xmeta.AppSpecOptions{
			Name: "SmokeApp",
			Auth: &xmeta.AuthBinding{
				UserTable:      xmeta.ObjectNameFromString("users"),
				UserIDColumn:   "id",
				LoginColumn:    "email",
				PasswordColumn: "passwd",
				Options: map[string]string{
					"LoginProcedureName":      "proc_u_login",
					"LoginProcedureStatement": "SELECT id FROM users WHERE email = ?",
				},
			},
			RoleName: "u",
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(out)
	if err != nil {
		t.Fatal(err)
	}
	var spec tavola.Spec
	if err := json.Unmarshal(data, &spec); err != nil {
		t.Fatal(err)
	}
	if spec.Project.Name != "SmokeApp" {
		t.Fatalf("project = %q", spec.Project.Name)
	}
	if len(spec.Schema.Tables) != 1 || spec.Schema.Tables[0].Name != "users" {
		t.Fatalf("tables = %#v", spec.Schema.Tables)
	}
	if len(spec.Schema.Procedures) != 1 || spec.Schema.Procedures[0].Name != "proc_u_login" {
		t.Fatalf("procedures = %#v", spec.Schema.Procedures)
	}
	if len(spec.Introspection.WarningDetails) == 0 {
		t.Fatalf("warningDetails should mirror warning strings: %#v", spec.Introspection)
	}
}
