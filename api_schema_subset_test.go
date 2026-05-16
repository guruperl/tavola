package tavola

import (
	"encoding/json"
	"fmt"
	"maps"
	"math"
	"os"
	"reflect"
	"slices"
	"strings"
	"testing"
)

func assertMatchesAPISchema(t *testing.T, value any) {
	t.Helper()
	schemaData, err := os.ReadFile("docs/api.schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var schema map[string]any
	if err := json.Unmarshal(schemaData, &schema); err != nil {
		t.Fatal(err)
	}
	var normalized any
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &normalized); err != nil {
		t.Fatal(err)
	}
	var errors []string
	validateJSONSchemaSubset(schema, normalized, "$", &errors)
	if len(errors) > 0 {
		t.Fatalf("api schema errors:\n%s", strings.Join(errors, "\n"))
	}
}

func validateJSONSchemaSubset(schema map[string]any, value any, path string, errors *[]string) {
	if want, ok := schema["const"]; ok {
		if !jsonSame(value, want) {
			*errors = append(*errors, fmt.Sprintf("%s must equal %v", path, want))
			return
		}
	}
	if typ, ok := schema["type"]; ok && !jsonMatchesType(value, typ) {
		*errors = append(*errors, fmt.Sprintf("%s must be %s", path, jsonTypeLabel(typ)))
		return
	}
	properties, hasProperties := schema["properties"].(map[string]any)
	if schema["type"] == "object" || hasProperties {
		object, ok := value.(map[string]any)
		if !ok {
			return
		}
		for _, key := range schemaStringSlice(schema["required"]) {
			if _, ok := object[key]; !ok {
				*errors = append(*errors, path+"."+key+" is required")
			}
		}
		if additional, ok := schema["additionalProperties"].(bool); ok && !additional {
			allowed := map[string]bool{}
			for key := range properties {
				allowed[key] = true
			}
			for _, key := range slices.Sorted(maps.Keys(object)) {
				if !allowed[key] {
					*errors = append(*errors, path+"."+key+" is not allowed")
				}
			}
		}
		for _, key := range slices.Sorted(maps.Keys(properties)) {
			if child, ok := object[key]; ok {
				validateJSONSchemaSubset(properties[key].(map[string]any), child, path+"."+key, errors)
			}
		}
	}
	items, hasItems := schema["items"].(map[string]any)
	if schema["type"] == "array" || hasItems {
		array, ok := value.([]any)
		if !ok {
			return
		}
		if minItems, ok := schema["minItems"].(float64); ok && len(array) < int(minItems) {
			*errors = append(*errors, fmt.Sprintf("%s must contain at least %d item(s)", path, int(minItems)))
		}
		if hasItems {
			for i, item := range array {
				validateJSONSchemaSubset(items, item, fmt.Sprintf("%s[%d]", path, i), errors)
			}
		}
	}
}

func jsonMatchesType(value any, typ any) bool {
	if choices, ok := typ.([]any); ok {
		for _, choice := range choices {
			if jsonMatchesType(value, choice) {
				return true
			}
		}
		return false
	}
	switch typ {
	case "null":
		return value == nil
	case "object":
		_, ok := value.(map[string]any)
		return ok
	case "array":
		_, ok := value.([]any)
		return ok
	case "boolean":
		_, ok := value.(bool)
		return ok
	case "string":
		_, ok := value.(string)
		return ok
	case "integer":
		number, ok := value.(float64)
		return ok && math.Trunc(number) == number
	case "number":
		_, ok := value.(float64)
		return ok
	default:
		return false
	}
}

func jsonSame(left, right any) bool {
	ln, lok := left.(float64)
	rn, rok := right.(float64)
	if lok && rok {
		return ln == rn
	}
	return reflect.DeepEqual(left, right)
}

func schemaStringSlice(value any) []string {
	raw, ok := value.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(raw))
	for _, item := range raw {
		if text, ok := item.(string); ok {
			out = append(out, text)
		}
	}
	return out
}

func jsonTypeLabel(value any) string {
	if choices, ok := value.([]any); ok {
		labels := make([]string, 0, len(choices))
		for _, choice := range choices {
			labels = append(labels, fmt.Sprint(choice))
		}
		return strings.Join(labels, " or ")
	}
	return fmt.Sprint(value)
}
