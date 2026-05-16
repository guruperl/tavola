package tavola

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestComponentJSONGeneratedAndOverrides(t *testing.T) {
	spec := componentJSONTestSpec()
	table := componentJSONTestTable()
	component := componentJSONTestComponent()

	generatedText, err := componentJSONText("", spec, component, table)
	if err != nil {
		t.Fatal(err)
	}
	generated := decodeJSONMap(t, generatedText)
	if generated["current_table"] != "widget" {
		t.Fatalf("current_table = %v", generated["current_table"])
	}
	if got := stringSliceFromAny(generated["insert_pars"]); !slices.Equal(got, []string{"name", "created"}) {
		t.Fatalf("insert_pars = %#v", got)
	}

	override := componentJSONOverride()
	inlineRaw := json.RawMessage(mustMarshalJSONString(t, override))
	inlineComponent := componentJSONTestComponent()
	inlineComponent.ComponentJSON = inlineRaw
	inlineText, err := componentJSONText("", spec, inlineComponent, table)
	if err != nil {
		t.Fatal(err)
	}
	inlineDecoded := decodeJSONMap(t, inlineText)
	if inlineDecoded["current_table"] != "widget" {
		t.Fatalf("inline componentJson current_table = %v", inlineDecoded["current_table"])
	}
	inlineActions := inlineDecoded["actions"].(map[string]any)
	topicsGroups := stringSliceFromAny(inlineActions["topics"].(map[string]any)["groups"])
	if !slices.Equal(topicsGroups, []string{"p", "a"}) {
		t.Fatalf("inline componentJson topics groups = %#v", topicsGroups)
	}

	tmp := t.TempDir()
	fileText := mustMarshalIndentedJSONString(t, override)
	if err := os.WriteFile(filepath.Join(tmp, "component.json"), []byte(fileText), 0644); err != nil {
		t.Fatal(err)
	}
	fileOut, err := componentJSONText(tmp, spec, Component{
		Name: "widget", Description: "Widgets", Table: "widget", Public: []string{"topics"},
		Roles:             map[string][]string{"a": {"startnew", "insert", "edit", "update", "topics"}},
		ComponentJSONFile: "component.json",
	}, table)
	if err != nil {
		t.Fatal(err)
	}
	if fileOut != fileText {
		t.Fatalf("componentJsonFile text changed:\n%s", fileOut)
	}
}

func TestComponentJSONRejectsInvalidOverrides(t *testing.T) {
	spec := componentJSONTestSpec()
	table := componentJSONTestTable()
	component := componentJSONTestComponent()

	cases := []struct {
		name     string
		override any
		want     string
	}{
		{name: "invalid actions", override: mapWith(componentJSONOverride(), "actions", nil), want: "actions must be an object"},
		{name: "invalid action structure", override: mapWith(componentJSONOverride(), "actions", map[string]any{"topics": []string{"p"}}), want: "actions.topics must be an object"},
		{name: "invalid parameter field", override: mapWith(componentJSONOverride(), "insert_pars", "name"), want: "insert_pars must be an array"},
		{name: "invalid parameter item", override: mapWith(componentJSONOverride(), "insert_pars", []any{"name", 1}), want: "insert_pars[1] must be a string"},
		{name: "invalid current key", override: mapWith(componentJSONOverride(), "current_key", nil), want: "current_key must be a string"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := componentJSONText("", spec, Component{
				Name: "widget", Description: component.Description, Table: component.Table,
				Public: component.Public, Roles: component.Roles,
				ComponentJSON: json.RawMessage(mustMarshalJSONString(t, tc.override)),
			}, table)
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("error = %v, want containing %q", err, tc.want)
			}
		})
	}

	_, err := componentJSONText("", spec, Component{
		Name: "widget", Description: component.Description, Table: component.Table,
		Public: component.Public, Roles: component.Roles,
		ComponentJSON: json.RawMessage("{bad json"),
	}, table)
	if err == nil || !strings.Contains(err.Error(), "invalid component JSON override") {
		t.Fatalf("invalid inline JSON error = %v", err)
	}

	tmp := t.TempDir()
	badFile := mapWith(componentJSONOverride(), "topics_pars", map[string]any{})
	if err := os.WriteFile(filepath.Join(tmp, "bad.json"), []byte(mustMarshalJSONString(t, badFile)), 0644); err != nil {
		t.Fatal(err)
	}
	_, err = componentJSONText(tmp, spec, Component{
		Name: "widget", Description: component.Description, Table: component.Table,
		Public: component.Public, Roles: component.Roles,
		ComponentJSONFile: "bad.json",
	}, table)
	if err == nil || !strings.Contains(err.Error(), "topics_pars must be an array") {
		t.Fatalf("invalid componentJsonFile error = %v", err)
	}
}

func componentJSONTestSpec() *Spec {
	return &Spec{Project: Project{PublicRole: "p"}}
}

func componentJSONTestTable() tableRow {
	return tableRow{
		Name: "widget", Key: "widget_id", AutoKey: "widget_id",
		Insert: []string{"name", "created"},
		Edit:   []string{"widget_id", "name", "created"},
		Update: []string{"widget_id", "name"},
		Topics: []string{"widget_id", "name", "created"},
	}
}

func componentJSONTestComponent() Component {
	return Component{
		Name: "widget", Description: "Widgets", Table: "widget", Public: []string{"topics"},
		Roles: map[string][]string{"a": {"startnew", "insert", "edit", "update", "topics"}},
	}
}

func componentJSONOverride() map[string]any {
	return map[string]any{
		"actions": map[string]any{
			"topics":   map[string]any{"groups": []string{"p", "a"}},
			"startnew": map[string]any{"groups": []string{"a"}, "options": []string{"no_db", "no_method"}},
		},
		"current_table":   "widget",
		"current_key":     "widget_id",
		"current_id_auto": "widget_id",
		"insert_pars":     []string{"name", "created"},
		"edit_pars":       []string{"widget_id", "name", "created"},
		"update_pars":     []string{"widget_id", "name"},
		"topics_pars":     []string{"widget_id", "name", "created"},
	}
}

func mapWith(base map[string]any, key string, value any) map[string]any {
	out := map[string]any{}
	for k, v := range base {
		out[k] = v
	}
	out[key] = value
	return out
}

func decodeJSONMap(t *testing.T, text string) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal([]byte(text), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func mustMarshalIndentedJSONString(t *testing.T, value any) string {
	t.Helper()
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	return string(data) + "\n"
}
