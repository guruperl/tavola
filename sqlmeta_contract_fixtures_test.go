package tavola

import (
	"encoding/json"
	"os"
	"slices"
	"strings"
	"testing"

	"github.com/genelet/sqlmeta/xmeta"
)

func TestSQLMetaProjectSpecAndGeneratedPHPArchive(t *testing.T) {
	spec, err := LoadTavolaSpecFile("specs/sqlmeta.project.json")
	if err != nil {
		t.Fatal(err)
	}
	if err := ValidateTavolaSpec(spec); err != nil {
		t.Fatalf("ValidateTavolaSpec: %v", err)
	}
	if spec.Introspection == nil || spec.Introspection.Source != "sqlmeta" {
		t.Fatalf("unexpected introspection: %#v", spec.Introspection)
	}
	warnings := strings.Join(spec.Introspection.Warnings, "\n")
	for _, want := range []string{"manual primary key override", "without a login procedure"} {
		if !strings.Contains(warnings, want) {
			t.Fatalf("expected warning containing %q, got:\n%s", want, warnings)
		}
	}
	codes := map[string]bool{}
	for i, detail := range spec.Introspection.WarningDetails {
		codes[detail.Code] = true
		if detail.Code == "" || detail.Code == xmeta.DiagnosticUnknown {
			t.Fatalf("warning detail has unstable code: %#v", detail)
		}
		if detail.Message != spec.Introspection.Warnings[i] {
			t.Fatalf("warning detail message = %q, want %q", detail.Message, spec.Introspection.Warnings[i])
		}
	}
	if !codes[xmeta.DiagnosticTableManualPK] || !codes[xmeta.DiagnosticAuthMissingLoginProcedure] {
		t.Fatalf("missing expected warning codes: %#v", codes)
	}
	if spec.Project.PublicRole != "p" {
		t.Fatalf("public role = %q", spec.Project.PublicRole)
	}
	tables := tablesByName(spec.Schema.Tables)
	if tables["users"].PrimaryKey != "public_id" || tables["users"].AutoKey != "id" {
		t.Fatalf("users key = %q auto = %q", tables["users"].PrimaryKey, tables["users"].AutoKey)
	}
	roles := rolesByName(spec.Roles)
	role := roles["u"]
	if role.Table != "users" || role.Fields.ID != "public_id" || role.Fields.Login != "email" || role.Fields.Password != "passwd" || role.Fields.FirstName != "firstname" || role.Fields.LastName != "lastname" {
		t.Fatalf("unexpected auth role fields: %#v", role)
	}
	components := componentsByName(spec.Components)
	if len(components["users"].Roles["u"]) == 0 || len(components["posts"].Roles["u"]) == 0 {
		t.Fatalf("protected grants missing: %#v", components)
	}
	if len(components["audit_log"].Roles) != 0 {
		t.Fatalf("audit_log should not have protected grants: %#v", components["audit_log"].Roles)
	}
	if !slices.Equal(components["posts"].Roles["u"], []string{"startnew", "insert", "edit", "update", "delete", "topics"}) {
		t.Fatalf("posts role actions = %#v", components["posts"].Roles["u"])
	}

	archive, err := GenerateFromTavolaSpec(spec, GenerateOptions{Language: LanguagePHP, Deterministic: true})
	if err != nil {
		t.Fatal(err)
	}
	files := filesByPath(archive)
	config := decodeArchiveJSON(t, files["conf/config.json"])
	if config["Pubrole"] != "p" {
		t.Fatalf("config Pubrole = %v", config["Pubrole"])
	}
	uConfig := config["Roles"].(map[string]any)["u"].(map[string]any)
	if uConfig["Id_name"] != "public_id" {
		t.Fatalf("config role Id_name = %v", uConfig["Id_name"])
	}
	if got := stringSliceFromAny(uConfig["Attributes"]); !slices.Equal(got, []string{"public_id", "email", "u_firstname", "u_lastname"}) {
		t.Fatalf("config role attributes = %#v", got)
	}
	api := decodeArchiveJSON(t, files["api.json"])
	if maybeJSONComponentAction(api, "users", "topics") == nil || maybeJSONComponentAction(api, "posts", "topics") == nil {
		t.Fatalf("generated API missing users/posts components")
	}
	postsTopics := jsonComponentAction(t, api, "posts", "topics")
	if got := slices.Sorted(slices.Values(stringSliceFromAny(postsTopics["allowed_groups"]))); !slices.Equal(got, []string{"p", "u"}) {
		t.Fatalf("posts topics groups = %#v", got)
	}
}

func TestManualPKFKProjectFixture(t *testing.T) {
	spec := readContractProject(t, "manual_pk_fk")
	if spec.Project.Name != "SqlmetaApp" || spec.Introspection == nil || spec.Introspection.Source != "sqlmeta" {
		t.Fatalf("unexpected project fixture metadata: %#v", spec.Project)
	}
	tables := map[string]Table{}
	for _, table := range spec.Schema.Tables {
		tables[table.Name] = table
	}
	if tables["users"].PrimaryKey != "public_id" || tables["users"].AutoKey != "id" {
		t.Fatalf("users key = %q auto = %q", tables["users"].PrimaryKey, tables["users"].AutoKey)
	}
	components := map[string]Component{}
	for _, component := range spec.Components {
		components[component.Name] = component
	}
	if len(components["posts"].Roles["u"]) == 0 || len(components["users"].Roles["u"]) == 0 {
		t.Fatalf("role grants missing from generated fixture: %#v", components)
	}
	if len(components["audit_log"].Roles["u"]) != 0 {
		t.Fatalf("unrelated audit_log should remain public-only: %#v", components["audit_log"].Roles)
	}

	assertWarningSnapshot(t, "manual_pk_fk", spec)
}

func TestInvalidOverridesProjectFixture(t *testing.T) {
	spec := readContractProject(t, "invalid_overrides")
	if err := ValidateTavolaSpec(spec); err != nil {
		t.Fatalf("ValidateTavolaSpec: %v", err)
	}
	if spec.Project.Name != "SqlmetaApp" || spec.Introspection == nil || spec.Introspection.Source != "sqlmeta" {
		t.Fatalf("unexpected project fixture metadata: %#v", spec.Project)
	}
	components := map[string]Component{}
	for _, component := range spec.Components {
		components[component.Table] = component
	}
	if len(components["users"].Roles["u"]) == 0 || len(components["posts"].Roles["u"]) == 0 {
		t.Fatalf("expected valid auth-scope grants, components = %#v", components)
	}
	for _, table := range []string{"audit_log", "memberships", "archive.teams", "teams"} {
		if len(components[table].Roles["u"]) != 0 {
			t.Fatalf("unrelated table %s should not receive protected role grants: %#v", table, components[table].Roles)
		}
	}
	warnings := strings.Join(spec.Introspection.Warnings, "\n")
	for _, want := range []string{
		"manual primary key users_missing_public_id_pk on users references missing column missing_public_id",
		"manual foreign key posts_ambiguous_team_fk parent table \"teams\": ambiguous table name matched archive.teams, public.teams",
		"manual foreign key memberships_user_composite_fk on memberships has composite columns; skipped role scope edge",
		"manual foreign key memberships_user_composite_fk on memberships has composite columns; skipped virtual schema edge",
		"manual foreign key posts_missing_child_fk on posts references missing child column missing_user_id",
		"auth role was generated without a login procedure",
	} {
		if !strings.Contains(warnings, want) {
			t.Fatalf("expected warning containing %q, got:\n%s", want, warnings)
		}
	}
	assertWarningSnapshot(t, "invalid_overrides", spec)
}

func tablesByName(tables []Table) map[string]Table {
	out := map[string]Table{}
	for _, table := range tables {
		out[table.Name] = table
	}
	return out
}

func rolesByName(roles []Role) map[string]Role {
	out := map[string]Role{}
	for _, role := range roles {
		out[role.Name] = role
	}
	return out
}

func TestMissingAuthTableErrorFixture(t *testing.T) {
	scenario, err := xmeta.LoadContractScenario(xmeta.ContractScenarioMissingAuthTable)
	if err != nil {
		t.Fatal(err)
	}
	_, err = BuildTavolaSpecFromSQLMeta(scenario.Meta, SQLMetaGenerateOptions{
		GenerateOptions: GenerateOptions{
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
		},
		AppSpec: xmeta.AppSpecOptions{
			Name:            scenario.AppName,
			Auth:            scenario.Auth,
			RoleName:        scenario.RoleName,
			SchemaOverrides: scenario.SchemaOverrides,
		},
	})
	if err == nil {
		t.Fatal("expected missing auth table error")
	}
	data, readErr := os.ReadFile("testdata/sqlmeta/contracts/missing_auth_table.tavola_error.txt")
	if readErr != nil {
		t.Fatal(readErr)
	}
	if got := strings.TrimSpace(string(data)); got != err.Error() {
		t.Fatalf("error snapshot = %q, want %q", got, err.Error())
	}
}

func readContractProject(t *testing.T, scenario string) *Spec {
	t.Helper()
	data, err := os.ReadFile("testdata/sqlmeta/contracts/" + scenario + ".project.json")
	if err != nil {
		t.Fatal(err)
	}
	spec := &Spec{}
	if err := json.Unmarshal(data, spec); err != nil {
		t.Fatal(err)
	}
	return spec
}

func assertWarningSnapshot(t *testing.T, scenario string, spec *Spec) {
	t.Helper()
	warnings, err := os.ReadFile("testdata/sqlmeta/contracts/" + scenario + ".warnings.txt")
	if err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(string(warnings)) != strings.Join(spec.Introspection.Warnings, "\n") {
		t.Fatalf("%s warning snapshot does not match project JSON", scenario)
	}
	if spec.Introspection == nil {
		t.Fatalf("%s introspection is nil", scenario)
	}
	if got := len(spec.Introspection.WarningDetails); got != len(spec.Introspection.Warnings) {
		t.Fatalf("%s warning detail count = %d, want %d", scenario, got, len(spec.Introspection.Warnings))
	}
	for i, detail := range spec.Introspection.WarningDetails {
		if detail.Message != spec.Introspection.Warnings[i] {
			t.Fatalf("%s warningDetails[%d].message = %q, want %q", scenario, i, detail.Message, spec.Introspection.Warnings[i])
		}
		if detail.Code == "" || detail.Code == xmeta.DiagnosticUnknown {
			t.Fatalf("%s warningDetails[%d] has unknown code for %q", scenario, i, detail.Message)
		}
	}
}
