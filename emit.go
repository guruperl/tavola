package tavola

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
)

//go:embed docs/api.schema.json
var embeddedAPISchema string

func emitArchive(model *generationModel) (*Archive, error) {
	archive := NewArchive()
	archive.AddString("conf/init.sql", initSQL(model))
	archive.AddMode("logs/debug.log", nil, 0777)
	config, err := configJSON(model)
	if err != nil {
		return nil, err
	}
	archive.AddString("conf/config.json", config)
	manifest := apiManifest(model)
	archive.AddString("api.json", mustJSON(manifest))
	archive.AddString("openapi.json", mustJSON(openAPIDocument(manifest)))
	archive.AddString("docs/api.md", apiDocs(manifest))
	archive.AddString("docs/api.schema.json", apiSchemaJSON())

	switch model.Options.Language {
	case LanguagePHP:
		emitPHP(archive, model)
	case LanguagePerl:
		emitPerl(archive, model)
	case LanguageGo:
		emitGo(archive, model, manifest)
	default:
		return nil, fmt.Errorf("unsupported language %q", model.Options.Language)
	}
	return archive, nil
}

func initSQL(model *generationModel) string {
	var b strings.Builder
	for _, table := range model.Tables {
		b.WriteString("\nDROP TABLE IF EXISTS ")
		b.WriteString(table.Name)
		b.WriteString(";\n")
		b.WriteString(strings.TrimSuffix(table.Statement, ";"))
		b.WriteString(";\n\n")
	}
	if len(model.Procedures) == 0 {
		return b.String()
	}
	switch dbFamily(model.Project.DBType) {
	case "sqlite":
		b.WriteString("\n-- SQLite does not support stored procedure DDL.\n")
		for _, proc := range model.Procedures {
			b.WriteString("-- Procedure ")
			b.WriteString(proc.Name)
			b.WriteString(" is exposed in config/API only.\n")
		}
		b.WriteString("\n")
	case "postgresql":
		for _, proc := range model.Procedures {
			b.WriteString("\nDROP PROCEDURE IF EXISTS ")
			b.WriteString(proc.Name)
			b.WriteString(";\n")
			b.WriteString(strings.TrimSuffix(proc.Statement, ";"))
			b.WriteString(";\n\n")
		}
	default:
		for _, proc := range model.Procedures {
			b.WriteString("\nDROP PROCEDURE IF EXISTS ")
			b.WriteString(proc.Name)
			b.WriteString(";\nDELIMITER //\n")
			b.WriteString(strings.TrimSuffix(proc.Statement, ";"))
			b.WriteString("//\nDELIMITER ;\n\n")
		}
	}
	return b.String()
}

func configJSON(model *generationModel) (string, error) {
	cfg := map[string]any{
		"Document_root": model.Project.DocumentRoot,
		"Project":       model.Project.Project,
		"Server_url":    model.Project.ServerURL,
		"Script":        model.Project.Script,
		"Pubrole":       model.Project.PublicRole,
		"Template":      model.Project.Template,
		"Uploaddir":     model.Project.UploadDir,
		"Secret":        deterministicHex(model.Options, 100),
		"Db":            []string{pdoDSN(model.Project), model.Project.DBUser, model.Project.DBPass},
		"Log": map[string]any{
			"Filename": model.Project.LogFile,
			"Level":    "info",
		},
		"Chartags": map[string]any{
			"html": map[string]any{"Content_type": "text/html; charset='UTF-8'"},
			"json": map[string]any{"Content_type": "application/json; charset='UTF-8'", "Case": 1},
		},
		"Roles": map[string]any{},
	}
	roles := cfg["Roles"].(map[string]any)
	for _, role := range model.Roles {
		roles[role.Name] = roleConfig(model, role)
	}
	if model.Options.Language == LanguageGo {
		cfg["DocumentRoot"] = cfg["Document_root"]
		cfg["ServerURL"] = cfg["Server_url"]
		cfg["UploadDir"] = cfg["Uploaddir"]
		cfg["ConnectArray"] = connectArray(model.Project)
		cfg["DefaultActions"] = map[string]string{
			"GET":      firstNonEmpty(model.Project.DefaultAction, "topics"),
			"GET_item": "edit",
			"POST":     "insert",
			"PUT":      "update",
			"DELETE":   "delete",
		}
		delete(cfg, "Document_root")
		delete(cfg, "Server_url")
		delete(cfg, "Uploaddir")
		delete(cfg, "Db")
		for _, v := range roles {
			roleMap := v.(map[string]any)
			roleMap["MaxAge"] = roleMap["Max_age"]
			delete(roleMap, "Max_age")
			for _, issuer := range roleMap["Issuers"].(map[string]any) {
				issuerMap := issuer.(map[string]any)
				issuerMap["InPars"] = issuerMap["In_pars"]
				issuerMap["OutPars"] = issuerMap["Out_pars"]
				delete(issuerMap, "In_pars")
				delete(issuerMap, "Out_pars")
			}
		}
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data) + "\n", nil
}

func roleConfig(model *generationModel, role roleRow) map[string]any {
	login := strings.ToLower(model.Project.Project[:1]) + model.Project.Project[1:]
	domain := login + ".example.test"
	proc := role.ProcedureName
	authen := firstNonEmpty(role.Authen, "db")
	issuer := map[string]any{
		"Default":    true,
		"Screen":     1,
		"Credential": []string{role.FieldLogin, role.FieldPassword, "direct", "t" + role.Name},
		"Sql":        proc,
		"In_pars":    []string{role.FieldLogin, role.FieldPassword},
		"Out_pars": []string{
			role.FieldID,
			role.FieldLogin,
			role.Name + "_" + role.FieldFirstName,
			role.Name + "_" + role.FieldLastName,
		},
	}
	out := map[string]any{
		"Id_name":    role.FieldID,
		"Attributes": []string{role.FieldID, role.FieldLogin, role.Name + "_" + role.FieldFirstName, role.Name + "_" + role.FieldLastName},
		"Type_id":    role.ID,
		"Surface":    "t" + role.Name,
		"Domain":     domain,
		"Duration":   86400,
		"Max_age":    86400,
		"Secret":     deterministicHex(model.Options, 100),
		"Coding":     deterministicHex(model.Options, 100),
		"Logout":     "/",
		"Issuers":    map[string]any{authen: issuer},
	}
	if role.IsAdmin != 0 {
		out["Is_admin"] = true
	}
	return out
}

func pdoDSN(p projectRow) string {
	switch dbFamily(p.DBType) {
	case "sqlite":
		return "sqlite:" + p.DBName
	case "postgresql":
		var parts []string
		if p.Host != "" {
			parts = append(parts, "host="+p.Host)
		}
		if p.Port != "" {
			parts = append(parts, "port="+p.Port)
		}
		parts = append(parts, "dbname="+p.DBName)
		return "pgsql:" + strings.Join(parts, ";")
	default:
		var parts []string
		if p.Host != "" {
			parts = append(parts, "host="+p.Host)
		}
		if p.Port != "" {
			parts = append(parts, "port="+p.Port)
		}
		parts = append(parts, "dbname="+p.DBName)
		return "mysql:" + strings.Join(parts, ";")
	}
}

func connectArray(p projectRow) []string {
	switch dbFamily(p.DBType) {
	case "sqlite":
		return []string{"sqlite3", p.DBName}
	case "postgresql":
		return []string{"postgres", p.DBUser, p.DBPass, firstNonEmpty(p.Host, "127.0.0.1"), firstNonEmpty(p.Port, "5432"), p.DBName}
	default:
		return []string{"mysql", p.DBUser, p.DBPass, firstNonEmpty(p.Host, "127.0.0.1"), firstNonEmpty(p.Port, "3306"), p.DBName}
	}
}

func apiManifest(model *generationModel) map[string]any {
	var roles []map[string]any
	roles = append(roles, map[string]any{
		"name":          model.Project.PublicRole,
		"public":        true,
		"auth_required": false,
		"default": map[string]any{
			"component": model.Project.DefaultComp,
			"action":    model.Project.DefaultAction,
		},
	})
	for _, role := range model.Roles {
		roles = append(roles, map[string]any{
			"name":          role.Name,
			"public":        false,
			"auth_required": true,
			"authen":        role.Authen,
			"description":   role.Description,
			"is_admin":      role.IsAdmin != 0,
			"is_auto":       role.IsAuto != 0,
			"default":       map[string]any{"component": role.DefaultComponent, "action": role.DefaultAction},
			"fields": map[string]any{
				"id": role.FieldID, "login": role.FieldLogin, "password": role.FieldPassword,
				"firstname": role.FieldFirstName, "lastname": role.FieldLastName,
			},
			"restriction": role.Restriction,
			"login": map[string]any{
				"method":      firstNonEmpty(role.Authen, "db"),
				"endpoint":    model.Project.Script + "/" + role.Name + "/json/login",
				"credentials": compactStrings(role.FieldLogin, role.FieldPassword),
				"sql":         role.ProcedureName,
			},
		})
	}
	var components []map[string]any
	for _, comp := range model.Components {
		var jsonData map[string]any
		_ = json.Unmarshal([]byte(comp.ComponentJS), &jsonData)
		actions := jsonData["actions"].(map[string]any)
		var manifestActions []map[string]any
		for _, action := range actionNames(actions) {
			item := actions[action].(map[string]any)
			groups := toStringSlice(item["groups"])
			if len(groups) == 0 {
				continue
			}
			manifestActions = append(manifestActions, map[string]any{
				"name":           action,
				"allowed_groups": groups,
				"public":         contains(groups, model.Project.PublicRole),
				"options":        nonNilStrings(toStringSlice(item["options"])),
				"request_params": nonNilStrings(requestParams(action, jsonData)),
				"primary_key":    jsonData["current_key"],
				"examples":       map[string]any{"json": example(model.Project.Script, groups[0], "json", comp.Name, action), "html": example(model.Project.Script, groups[0], "html", comp.Name, action)},
			})
		}
		components = append(components, map[string]any{
			"name":            comp.Name,
			"description":     comp.Description,
			"table":           jsonData["current_table"],
			"primary_key":     jsonData["current_key"],
			"current_id_auto": jsonData["current_id_auto"],
			"actions":         manifestActions,
		})
	}
	manifest := map[string]any{
		"format":           "tavola-api-manifest",
		"version":          1,
		"project":          map[string]any{"name": model.Project.Project, "script": model.Project.Script, "public_role": model.Project.PublicRole, "default": map[string]any{"component": model.Project.DefaultComp, "action": model.Project.DefaultAction}},
		"endpoint_pattern": "<script>/<role>/<tag>/<component>?action=<action>",
		"auth_requirements": map[string]any{
			"public_role":            model.Project.PublicRole,
			"protected_roles":        roleNames(model.Roles),
			"login_endpoint_pattern": "<script>/<role>/json/login",
			"session_effect":         "Successful login sets the role session/cookie used by later protected action calls.",
		},
		"roles":      roles,
		"components": components,
	}
	if model.Inspect != nil {
		manifest["introspection"] = map[string]any{
			"source":          model.Inspect.Source,
			"warnings":        nonNilStrings(model.Inspect.Warnings),
			"warning_details": model.Inspect.WarningDetails,
		}
	}
	return manifest
}

func openAPIDocument(manifest map[string]any) map[string]any {
	project := manifest["project"].(map[string]any)
	script := project["script"].(string)
	rolesRaw := manifest["roles"].([]map[string]any)
	var roles []string
	var protected []map[string]any
	for _, role := range rolesRaw {
		roles = append(roles, role["name"].(string))
		if _, ok := role["login"]; ok {
			protected = append(protected, role)
		}
	}
	paths := map[string]any{}
	if len(protected) > 0 {
		paths[script+"/{role}/json/login"] = map[string]any{"post": map[string]any{
			"summary":     "Log in as a protected role",
			"operationId": "tavolaLogin",
			"parameters":  []any{map[string]any{"name": "role", "in": "path", "required": true, "schema": map[string]any{"type": "string", "enum": roleNamesFromManifest(protected)}}},
			"responses":   tavolaResponses(),
		}}
	}
	components := manifest["components"].([]map[string]any)
	seen := map[string]int{}
	for _, comp := range components {
		name := comp["name"].(string)
		var actions []string
		params := map[string]any{}
		for _, action := range comp["actions"].([]map[string]any) {
			actions = append(actions, action["name"].(string))
			for _, param := range toStringSlice(action["request_params"]) {
				params[param] = map[string]any{"type": "string"}
			}
		}
		var parameters []any
		parameters = append(parameters,
			map[string]any{"name": "role", "in": "path", "required": true, "schema": map[string]any{"type": "string", "enum": roles}},
			map[string]any{"name": "action", "in": "query", "required": true, "schema": map[string]any{"type": "string", "enum": actions}},
		)
		for _, param := range sortedKeys(params) {
			parameters = append(parameters, map[string]any{"name": param, "in": "query", "required": false, "schema": params[param]})
		}
		paths[script+"/{role}/json/"+name] = map[string]any{"get": map[string]any{
			"summary":            name + " component action",
			"operationId":        operationID(name, seen),
			"parameters":         parameters,
			"responses":          tavolaResponses(),
			"x-tavola-component": map[string]any{"name": name, "table": comp["table"], "primary_key": comp["primary_key"]},
			"x-tavola-actions":   comp["actions"],
		}}
	}
	doc := map[string]any{
		"openapi": "3.0.3",
		"info": map[string]any{
			"title":       project["name"].(string) + " API",
			"version":     "1.0.0",
			"description": "Derived from Tavola api.json. Tavola action details are preserved in x-tavola-* extensions.",
		},
		"paths":                     paths,
		"components":                map[string]any{"schemas": map[string]any{"TavolaResponse": map[string]any{"type": "object", "additionalProperties": true}}},
		"x-tavola-source":           "api.json",
		"x-tavola-endpoint-pattern": manifest["endpoint_pattern"],
	}
	if introspection, ok := manifest["introspection"]; ok {
		doc["x-tavola-introspection"] = introspection
	}
	return doc
}

func apiDocs(manifest map[string]any) string {
	project := manifest["project"].(map[string]any)
	var b strings.Builder
	b.WriteString("# " + project["name"].(string) + " API\n\n")
	b.WriteString("Endpoint pattern:\n\n```text\n")
	b.WriteString(manifest["endpoint_pattern"].(string))
	b.WriteString("\n```\n\n")
	b.WriteString("Use `json` for API responses and `html` for server-rendered views when templates are present.\n\n")
	b.WriteString("## Components\n\n| Component | Action | Groups | Request Params | JSON Example |\n| --- | --- | --- | --- | --- |\n")
	for _, comp := range manifest["components"].([]map[string]any) {
		for _, action := range comp["actions"].([]map[string]any) {
			b.WriteString("| `")
			b.WriteString(comp["name"].(string))
			b.WriteString("` | `")
			b.WriteString(action["name"].(string))
			b.WriteString("` | ")
			b.WriteString(strings.Join(quoteList(toStringSlice(action["allowed_groups"])), ", "))
			b.WriteString(" | ")
			b.WriteString(strings.Join(quoteList(toStringSlice(action["request_params"])), ", "))
			b.WriteString(" | `")
			b.WriteString(action["examples"].(map[string]any)["json"].(string))
			b.WriteString("` |\n")
		}
	}
	if introspection, ok := manifest["introspection"].(map[string]any); ok {
		warnings := toStringSlice(introspection["warnings"])
		if len(warnings) > 0 {
			b.WriteString("\n## Introspection Warnings\n\n")
			for _, warning := range warnings {
				b.WriteString("- ")
				b.WriteString(warning)
				b.WriteString("\n")
			}
		}
	}
	return b.String()
}

func apiSchemaJSON() string {
	return embeddedAPISchema
}

func dbFamily(value string) string {
	normalized := strings.ToLower(value)
	normalized = strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, normalized)
	switch normalized {
	case "postgres", "postgresql", "pgsql":
		return "postgresql"
	case "sqlite", "sqlite3":
		return "sqlite"
	default:
		return "mysql"
	}
}

func safePath(name string) string {
	name = strings.ToLower(name)
	name = strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '_' {
			return r
		}
		return '-'
	}, name)
	name = strings.Trim(name, "-")
	if name == "" {
		return "app"
	}
	return name
}

func safeIdent(name, fallback string) string {
	name = strings.ToLower(name)
	name = strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '_' {
			return r
		}
		return '_'
	}, name)
	name = strings.Trim(name, "_")
	if name == "" {
		name = fallback
	}
	if name[0] >= '0' && name[0] <= '9' {
		name = fallback + "_" + name
	}
	if goKeywords[name] {
		name = fallback + "_" + name
	}
	return name
}

var goKeywords = map[string]bool{"break": true, "default": true, "func": true, "interface": true, "select": true, "case": true, "defer": true, "go": true, "map": true, "struct": true, "chan": true, "else": true, "goto": true, "package": true, "switch": true, "const": true, "fallthrough": true, "if": true, "range": true, "type": true, "continue": true, "for": true, "import": true, "return": true, "var": true}

func componentDir(name string) string {
	return filepath.ToSlash(filepath.Clean(safePath(name)))
}

func ucfirst(name string) string {
	if name == "" {
		return ""
	}
	return strings.ToUpper(name[:1]) + name[1:]
}

func compactStrings(values ...string) []string {
	var out []string
	for _, value := range values {
		if value != "" {
			out = append(out, value)
		}
	}
	return out
}

func nonNilStrings(values []string) []string {
	if values == nil {
		return []string{}
	}
	return values
}

func roleNames(roles []roleRow) []string {
	out := make([]string, 0, len(roles))
	for _, role := range roles {
		out = append(out, role.Name)
	}
	return out
}

func roleNamesFromManifest(roles []map[string]any) []string {
	out := make([]string, 0, len(roles))
	for _, role := range roles {
		out = append(out, role["name"].(string))
	}
	return out
}

func actionNames(actions map[string]any) []string {
	standard := []string{"topics", "startnew", "insert", "edit", "update", "delete"}
	seen := map[string]bool{}
	var out []string
	for _, action := range standard {
		if _, ok := actions[action]; ok {
			out = append(out, action)
			seen[action] = true
		}
	}
	for key := range actions {
		if !seen[key] {
			out = append(out, key)
		}
	}
	sort.Strings(out[len(standardIntersection(actions)):])
	return out
}

func standardIntersection(actions map[string]any) []string {
	var out []string
	for _, action := range []string{"topics", "startnew", "insert", "edit", "update", "delete"} {
		if _, ok := actions[action]; ok {
			out = append(out, action)
		}
	}
	return out
}

func toStringSlice(value any) []string {
	switch v := value.(type) {
	case []string:
		return append([]string(nil), v...)
	case []any:
		out := make([]string, 0, len(v))
		for _, item := range v {
			if s, ok := item.(string); ok {
				out = append(out, s)
			}
		}
		return out
	default:
		return nil
	}
}

func requestParams(action string, jsonData map[string]any) []string {
	switch action {
	case "startnew":
		return nil
	case "insert":
		return toStringSlice(jsonData["insert_pars"])
	case "edit":
		return toStringSlice(jsonData["edit_pars"])
	case "update":
		return toStringSlice(jsonData["update_pars"])
	case "topics":
		return toStringSlice(jsonData["topics_pars"])
	case "delete":
		if key, ok := jsonData["current_key"].(string); ok && key != "" {
			return []string{key}
		}
	}
	return nil
}

func example(script, role, tag, component, action string) string {
	return script + "/" + role + "/" + tag + "/" + component + "?action=" + action
}

func contains(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

func sortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func tavolaResponses() map[string]any {
	return map[string]any{"200": map[string]any{"description": "Tavola JSON response", "content": map[string]any{"application/json": map[string]any{"schema": map[string]any{"$ref": "#/components/schemas/TavolaResponse"}}}}}
}

func operationID(component string, seen map[string]int) string {
	base := "tavola" + ucfirst(safeIdent(component, "component")) + "Action"
	seen[base]++
	if seen[base] == 1 {
		return base
	}
	return fmt.Sprintf("%s_%d", base, seen[base])
}

func quoteList(values []string) []string {
	out := make([]string, len(values))
	for i, value := range values {
		out[i] = "`" + value + "`"
	}
	return out
}
