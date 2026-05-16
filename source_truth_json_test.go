package tavola

import (
	"encoding/json"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestSupportDeskSourceTruthSpecAndGeneratedArchives(t *testing.T) {
	spec, err := LoadTavolaSpecFile(filepath.Join("specs", "supportdesk.project.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err := ValidateTavolaSpec(spec); err != nil {
		t.Fatalf("ValidateTavolaSpec: %v", err)
	}
	if spec.Introspection == nil || spec.Introspection.Source != "sqlmeta" {
		t.Fatalf("unexpected introspection source: %#v", spec.Introspection)
	}
	if len(spec.Introspection.Warnings) != 0 {
		t.Fatalf("reviewed source-of-truth should have no warnings: %#v", spec.Introspection.Warnings)
	}
	if spec.Project.Default.Component != "tickets" {
		t.Fatalf("default component = %q", spec.Project.Default.Component)
	}
	if spec.Roles[0].Restriction != "status = 'active'" {
		t.Fatalf("role restriction = %q", spec.Roles[0].Restriction)
	}
	components := componentsByName(spec.Components)
	if !slices.Equal(components["tickets"].Public, []string{"topics"}) {
		t.Fatalf("tickets public actions = %#v", components["tickets"].Public)
	}
	if len(components["teams"].Public) != 0 || len(components["ticket_notes"].Public) != 0 {
		t.Fatalf("protected-only components leaked public actions")
	}
	if !slices.Equal(components["users"].Roles["u"], []string{"edit", "update", "topics"}) {
		t.Fatalf("users role actions = %#v", components["users"].Roles["u"])
	}
	if len(components["audit_events"].Roles) != 0 {
		t.Fatalf("audit_events should remain outside protected role grants: %#v", components["audit_events"].Roles)
	}

	for _, lang := range []Language{LanguagePHP, LanguagePerl, LanguageGo} {
		t.Run(string(lang), func(t *testing.T) {
			archive, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: lang, Deterministic: true})
			if err != nil {
				t.Fatal(err)
			}
			files := filesByPath(archive)
			for _, path := range []string{"api.json", "conf/config.json", "conf/init.sql", "openapi.json"} {
				if files[path] == "" {
					t.Fatalf("missing %s", path)
				}
			}
			api := decodeArchiveJSON(t, files["api.json"])
			config := decodeArchiveJSON(t, files["conf/config.json"])
			assertMatchesAPISchema(t, api)
			if jsonPathString(api, "project", "name") != "SupportDesk" {
				t.Fatalf("api project name = %q", jsonPathString(api, "project", "name"))
			}
			if jsonPathString(api, "project", "default", "component") != "tickets" {
				t.Fatalf("api default component = %q", jsonPathString(api, "project", "default", "component"))
			}
			role := jsonRoleByName(t, api, "u")
			if jsonPathString(role, "login", "sql") != "proc_u_login" {
				t.Fatalf("login SQL = %q", jsonPathString(role, "login", "sql"))
			}
			if config["Project"] != "SupportDesk" {
				t.Fatalf("config Project = %v", config["Project"])
			}
			attrs := stringSliceFromAny(config["Roles"].(map[string]any)["u"].(map[string]any)["Attributes"])
			if !slices.Equal(attrs, []string{"id", "email", "u_firstname", "u_lastname"}) {
				t.Fatalf("role attributes = %#v", attrs)
			}
			assertSupportDeskAPIActions(t, api, string(lang))
			if !strings.Contains(files["conf/init.sql"], "SQLite does not support stored procedure DDL") {
				t.Fatalf("%s init.sql missing SQLite procedure comment", lang)
			}
			if strings.Contains(files["conf/init.sql"], "DROP PROCEDURE") || strings.Contains(files["conf/init.sql"], "DELIMITER") {
				t.Fatalf("%s init.sql contains non-SQLite procedure syntax", lang)
			}
			if lang == LanguagePerl && !strings.Contains(files["script/app"], "Genelet::Dispatch::run") {
				t.Fatalf("generated Perl script/app missing dispatch call")
			}
		})
	}
}

func assertSupportDeskAPIActions(t *testing.T, api map[string]any, label string) {
	t.Helper()
	ticketTopics := jsonComponentAction(t, api, "tickets", "topics")
	if got := slices.Sorted(slices.Values(stringSliceFromAny(ticketTopics["allowed_groups"]))); !slices.Equal(got, []string{"p", "u"}) {
		t.Fatalf("%s tickets topics groups = %#v", label, got)
	}
	ticketInsert := jsonComponentAction(t, api, "tickets", "insert")
	if got := stringSliceFromAny(ticketInsert["allowed_groups"]); !slices.Equal(got, []string{"u"}) {
		t.Fatalf("%s tickets insert groups = %#v", label, got)
	}
	teamTopics := jsonComponentAction(t, api, "teams", "topics")
	if got := stringSliceFromAny(teamTopics["allowed_groups"]); !slices.Equal(got, []string{"u"}) {
		t.Fatalf("%s teams topics groups = %#v", label, got)
	}
	userTopics := jsonComponentAction(t, api, "users", "topics")
	if got := stringSliceFromAny(userTopics["allowed_groups"]); !slices.Equal(got, []string{"u"}) {
		t.Fatalf("%s users topics groups = %#v", label, got)
	}
	if action := maybeJSONComponentAction(api, "users", "insert"); action != nil {
		t.Fatalf("%s users insert should be absent", label)
	}
	if action := maybeJSONComponentAction(api, "users", "delete"); action != nil {
		t.Fatalf("%s users delete should be absent", label)
	}
}

func componentsByName(components []Component) map[string]Component {
	out := map[string]Component{}
	for _, component := range components {
		out[component.Name] = component
	}
	return out
}

func decodeArchiveJSON(t *testing.T, text string) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal([]byte(text), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func jsonPathString(object map[string]any, path ...string) string {
	var current any = object
	for _, key := range path {
		next, ok := current.(map[string]any)[key]
		if !ok {
			return ""
		}
		current = next
	}
	value, _ := current.(string)
	return value
}

func jsonRoleByName(t *testing.T, api map[string]any, name string) map[string]any {
	t.Helper()
	for _, raw := range api["roles"].([]any) {
		role := raw.(map[string]any)
		if role["name"] == name {
			return role
		}
	}
	t.Fatalf("role %s not found", name)
	return nil
}

func jsonComponentAction(t *testing.T, api map[string]any, component, action string) map[string]any {
	t.Helper()
	out := maybeJSONComponentAction(api, component, action)
	if out == nil {
		t.Fatalf("action %s.%s not found", component, action)
	}
	return out
}

func maybeJSONComponentAction(api map[string]any, component, action string) map[string]any {
	for _, rawComponent := range api["components"].([]any) {
		componentObject := rawComponent.(map[string]any)
		if componentObject["name"] != component {
			continue
		}
		for _, rawAction := range componentObject["actions"].([]any) {
			actionObject := rawAction.(map[string]any)
			if actionObject["name"] == action {
				return actionObject
			}
		}
	}
	return nil
}
