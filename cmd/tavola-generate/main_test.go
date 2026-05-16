package main

import (
	"strings"
	"testing"

	"github.com/guruperl/tavola"
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
