package tavola

import (
	"encoding/json"
	"slices"
	"strings"
	"testing"
)

func TestAPIManifestDocsAndOpenAPIContract(t *testing.T) {
	model := syntheticAPIModel(t)
	manifest := apiManifest(model)
	assertMatchesAPISchema(t, manifest)

	vehicle := manifestComponent(t, manifest, "vehicle")
	actionNames := manifestActionNames(t, vehicle)
	if want := []string{"topics", "insert", "makes", "years"}; !slices.Equal(actionNames, want) {
		t.Fatalf("vehicle actions = %#v, want %#v", actionNames, want)
	}

	actions := manifestActionsByName(t, vehicle)
	years := actions["years"]
	if years == nil {
		t.Fatal("custom years action missing")
	}
	if got := stringSliceFromAny(years["allowed_groups"]); !slices.Equal(got, []string{"u"}) {
		t.Fatalf("years allowed_groups = %#v", got)
	}
	if got := stringSliceFromAny(years["request_params"]); len(got) != 0 {
		t.Fatalf("years request_params = %#v, want empty", got)
	}
	if years["public"].(bool) {
		t.Fatal("years should be protected")
	}
	if actions["history"] != nil {
		t.Fatal("custom action without groups should be omitted")
	}

	docs := apiDocs(manifest)
	if !strings.Contains(docs, "| `vehicle` | `years` | `u` |  | `/example/app.php/u/json/vehicle?action=years` |") {
		t.Fatalf("docs missing protected custom action row:\n%s", docs)
	}
	if !strings.Contains(docs, "| `vehicle` | `makes` | `p` |  | `/example/app.php/p/json/vehicle?action=makes` |") {
		t.Fatalf("docs missing public custom action row:\n%s", docs)
	}

	openapi := openAPIDocument(manifest)
	vehiclePath := openapi["paths"].(map[string]any)["/example/app.php/{role}/json/vehicle"].(map[string]any)["get"].(map[string]any)
	actionParam := vehiclePath["parameters"].([]any)[1].(map[string]any)
	if got := stringSliceFromAny(actionParam["schema"].(map[string]any)["enum"]); !slices.Equal(got, []string{"topics", "insert", "makes", "years"}) {
		t.Fatalf("OpenAPI action enum = %#v", got)
	}
	openapiActions := openAPIActionsByName(t, vehiclePath)
	if openapiActions["years"] == nil {
		t.Fatal("OpenAPI extension missing years action")
	}
	if got := stringSliceFromAny(openapiActions["years"]["request_params"]); len(got) != 0 {
		t.Fatalf("OpenAPI years request_params = %#v, want empty", got)
	}
	if got := openapi["paths"].(map[string]any)["/example/app.php/{role}/json/a-b"].(map[string]any)["get"].(map[string]any)["operationId"]; got != "tavolaA_bAction" {
		t.Fatalf("first colliding operationId = %v", got)
	}
	if got := openapi["paths"].(map[string]any)["/example/app.php/{role}/json/a_b"].(map[string]any)["get"].(map[string]any)["operationId"]; got != "tavolaA_bAction_2" {
		t.Fatalf("second colliding operationId = %v", got)
	}
}

func syntheticAPIModel(t *testing.T) *generationModel {
	t.Helper()
	vehicleJSON := map[string]any{
		"actions": map[string]any{
			"years":   map[string]any{"groups": []string{"u"}},
			"makes":   map[string]any{"groups": []string{"p"}},
			"history": map[string]any{},
			"insert":  map[string]any{"groups": []string{"u"}},
			"topics":  map[string]any{"groups": []string{"p", "u"}},
		},
		"current_table":   "vehicle",
		"current_key":     "vehicle_id",
		"current_id_auto": "vehicle_id",
		"insert_pars":     []string{"make", "year"},
		"edit_pars":       []string{"vehicle_id", "make", "year"},
		"update_pars":     []string{"vehicle_id", "make", "year"},
		"topics_pars":     []string{"vehicle_id", "make", "year"},
	}
	collisionJSON := map[string]any{
		"actions":       map[string]any{"topics": map[string]any{"groups": []string{"p"}}},
		"current_table": "collision",
		"current_key":   "collision_id",
		"insert_pars":   []string{},
		"edit_pars":     []string{},
		"update_pars":   []string{},
		"topics_pars":   []string{"collision_id"},
	}
	return &generationModel{
		Project: projectRow{Project: "ExampleApp", Script: "/example/app.php", PublicRole: "p", DefaultComp: "vehicle", DefaultAction: "topics"},
		Roles: []roleRow{{
			Name: "u", Authen: "db", Description: "User", IsAuto: 1,
			DefaultComponent: "vehicle", DefaultAction: "topics",
			FieldID: "user_id", FieldLogin: "email", FieldPassword: "passwd",
			FieldFirstName: "firstname", FieldLastName: "lastname",
			ProcedureName: "proc_example_u",
		}},
		Components: []componentRow{
			{Name: "vehicle", Description: "Vehicles", ComponentJS: mustMarshalJSONString(t, vehicleJSON)},
			{Name: "a-b", Description: "Collision A", ComponentJS: mustMarshalJSONString(t, collisionJSON)},
			{Name: "a_b", Description: "Collision B", ComponentJS: mustMarshalJSONString(t, collisionJSON)},
		},
	}
}

func mustMarshalJSONString(t *testing.T, value any) string {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func manifestComponent(t *testing.T, manifest map[string]any, name string) map[string]any {
	t.Helper()
	for _, component := range manifest["components"].([]map[string]any) {
		if component["name"] == name {
			return component
		}
	}
	t.Fatalf("component %s not found", name)
	return nil
}

func manifestActionNames(t *testing.T, component map[string]any) []string {
	t.Helper()
	actions := component["actions"].([]map[string]any)
	out := make([]string, 0, len(actions))
	for _, action := range actions {
		out = append(out, action["name"].(string))
	}
	return out
}

func manifestActionsByName(t *testing.T, component map[string]any) map[string]map[string]any {
	t.Helper()
	out := map[string]map[string]any{}
	for _, action := range component["actions"].([]map[string]any) {
		out[action["name"].(string)] = action
	}
	return out
}

func openAPIActionsByName(t *testing.T, operation map[string]any) map[string]map[string]any {
	t.Helper()
	out := map[string]map[string]any{}
	for _, raw := range operation["x-tavola-actions"].([]map[string]any) {
		out[raw["name"].(string)] = raw
	}
	return out
}

func stringSliceFromAny(value any) []string {
	switch typed := value.(type) {
	case []string:
		return slices.Clone(typed)
	case []any:
		out := make([]string, 0, len(typed))
		for _, item := range typed {
			out = append(out, item.(string))
		}
		return out
	default:
		return nil
	}
}
