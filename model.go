package tavola

import (
	"cmp"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/genelet/sqlmeta/xmeta"
)

type generationModel struct {
	Project    projectRow
	Tables     []tableRow
	Procedures []procedureRow
	Roles      []roleRow
	Components []componentRow
	PublicACL  []aclRow
	RoleACL    []aclRow
	Other      otherRows
	Options    GenerateOptions
	Inspect    *Introspection
}

type projectRow struct {
	MemberID      int
	ProjectID     int
	DocumentRoot  string
	Project       string
	ServerURL     string
	Script        string
	Template      string
	UploadDir     string
	PublicRole    string
	DefaultComp   string
	DefaultAction string
	AdminRole     string
	AdminUser     string
	AdminPass     string
	LogFile       string
	DBType        string
	DBName        string
	DBUser        string
	DBPass        string
	Host          string
	Port          string
}

type tableRow struct {
	ID        int
	Name      string
	Key       string
	AutoKey   string
	Insert    []string
	Edit      []string
	Update    []string
	Topics    []string
	Statement string
	IsTavola  int
	Comment   string
}

type procedureRow struct {
	ID        int
	Name      string
	Statement string
	TableID   int
}

type roleRow struct {
	ID               int
	Name             string
	Description      string
	Authen           string
	IsAdmin          int
	IsAuto           int
	TableID          int
	DefaultComponent string
	DefaultAction    string
	FieldID          string
	FieldLogin       string
	FieldPassword    string
	FieldFirstName   string
	FieldLastName    string
	Restriction      string
	ProcedureName    string
}

type componentRow struct {
	ID                 int
	Name               string
	Description        string
	TableID            int
	TableName          string
	Key                string
	AutoKey            string
	Insert             []string
	Edit               []string
	Update             []string
	Topics             []string
	ComponentJS        string
	CurrentTable       []string
	GoFilterOverlay    string
	GoFilterOverlaySet bool
	GoModelOverlay     string
	GoModelOverlaySet  bool
}

type aclRow struct {
	ComponentID   int
	ComponentName string
	RoleID        int
	RoleName      string
	CRUD          string
	FieldID       string
	CurrentKey    string
	Insert        []string
	Edit          []string
	Update        []string
	Topics        []string
	InKey         string
	InMD5         string
	OutKey        string
	OutMD5        string
}

type otherRows struct {
	PublicLanding []landingRow
	AllComponents []componentListRow
	RoleLanding   []roleLandingRow
}

type landingRow struct {
	Component string
	Action    string
}

type componentListRow struct {
	Name string
}

type roleLandingRow struct {
	RoleID           int
	RoleName         string
	DefaultComponent string
	DefaultAction    string
	Component        string
	Level            int
	Action           string
	IsEdit           bool
	IsTopics         bool
	IsStartNew       bool
}

func buildGenerationModel(spec *Spec, opts GenerateOptions) (*generationModel, error) {
	if strings.TrimSpace(spec.Project.Name) == "" {
		return nil, fmt.Errorf("project.name is required")
	}
	lang := opts.Language
	if lang == "" {
		lang = LanguagePHP
	}
	if lang != LanguagePHP && lang != LanguagePerl && lang != LanguageGo {
		return nil, fmt.Errorf("unsupported language %q", lang)
	}
	opts.Language = lang
	if !opts.WebUI {
		opts.WebUI = false
	}
	memberID := spec.Owner.TypeID
	if memberID == 0 {
		memberID = 1
	}
	projectName := spec.Project.Name
	publicRole := firstNonEmpty(spec.Project.PublicRole, "p")
	defAction := firstNonEmpty(spec.Project.Default.Action, "topics")
	p := projectRow{
		MemberID:      memberID,
		ProjectID:     1,
		DocumentRoot:  "www",
		Project:       projectName,
		ServerURL:     "/" + safePath(projectName),
		Script:        firstNonEmpty(spec.Project.Script, "/"+safePath(projectName)+"/app.php"),
		Template:      "views",
		UploadDir:     "upload",
		PublicRole:    publicRole,
		DefaultComp:   spec.Project.Default.Component,
		DefaultAction: defAction,
		AdminRole:     "a",
		AdminUser:     "admin",
		AdminPass:     deterministicHex(opts, 8),
		LogFile:       "logs/debug.log",
		DBType:        spec.Datasource.Type,
		DBName:        firstNonEmpty(spec.Datasource.Database, spec.Datasource.Path),
		DBUser:        spec.Datasource.User,
		DBPass:        spec.Datasource.Password,
		Host:          spec.Datasource.Host,
		Port:          spec.Datasource.Port,
	}
	model := &generationModel{Project: p, Options: opts, Inspect: cloneIntrospection(spec.Introspection)}
	baseDir := specBaseDir(opts)
	tablesByName := map[string]tableRow{}
	tablesByID := map[int]tableRow{}
	for i, t := range spec.Schema.Tables {
		statement, err := specText(baseDir, t.Statement, t.StatementFile)
		if err != nil {
			return nil, fmt.Errorf("table %s: %w", t.Name, err)
		}
		row := tableRow{
			ID:        i + 1,
			Name:      t.Name,
			Key:       t.PrimaryKey,
			AutoKey:   t.AutoKey,
			Insert:    slices.Clone(t.Insert),
			Edit:      slices.Clone(t.Edit),
			Update:    slices.Clone(t.Update),
			Topics:    slices.Clone(t.Topics),
			Statement: strings.TrimSuffix(strings.TrimSpace(statement), ";"),
			Comment:   t.Comment,
		}
		model.Tables = append(model.Tables, row)
		tablesByName[row.Name] = row
		tablesByID[row.ID] = row
	}
	if len(model.Tables) == 0 {
		return nil, fmt.Errorf("schema.tables is required")
	}
	procedureByTable := map[int]procedureRow{}
	for i, proc := range spec.Schema.Procedures {
		statement, err := specText(baseDir, proc.Statement, proc.StatementFile)
		if err != nil {
			return nil, fmt.Errorf("procedure %s: %w", proc.Name, err)
		}
		tableID := 0
		if proc.Table != "" {
			tableID = tablesByName[proc.Table].ID
		}
		row := procedureRow{ID: i + 1, Name: proc.Name, Statement: strings.TrimSuffix(strings.TrimSpace(statement), ";"), TableID: tableID}
		model.Procedures = append(model.Procedures, row)
		if tableID != 0 {
			procedureByTable[tableID] = row
		}
	}
	rolesByName := map[string]roleRow{}
	for i, role := range spec.Roles {
		tableID := 0
		if role.Table != "" {
			tableID = tablesByName[role.Table].ID
		}
		proc := procedureByTable[tableID]
		row := roleRow{
			ID:               i + 1,
			Name:             role.Name,
			Description:      role.Description,
			Authen:           firstNonEmpty(role.Authen, "db"),
			IsAdmin:          role.IsAdmin,
			IsAuto:           role.IsAuto,
			TableID:          tableID,
			DefaultComponent: firstNonEmpty(role.Default.Component, spec.Project.Default.Component),
			DefaultAction:    firstNonEmpty(role.Default.Action, defAction),
			FieldID:          role.Fields.ID,
			FieldLogin:       role.Fields.Login,
			FieldPassword:    role.Fields.Password,
			FieldFirstName:   role.Fields.FirstName,
			FieldLastName:    role.Fields.LastName,
			Restriction:      role.Restriction,
			ProcedureName:    proc.Name,
		}
		model.Roles = append(model.Roles, row)
		rolesByName[row.Name] = row
	}
	for i, comp := range spec.Components {
		table, ok := tablesByName[comp.Table]
		if !ok {
			return nil, fmt.Errorf("component %s references missing table %s", comp.Name, comp.Table)
		}
		row := componentRow{
			ID:          i + 1,
			Name:        comp.Name,
			Description: comp.Description,
			TableID:     table.ID,
			TableName:   comp.Table,
			Key:         firstNonEmpty("", table.Key),
			AutoKey:     table.AutoKey,
			Insert:      table.Insert,
			Edit:        table.Edit,
			Update:      table.Update,
			Topics:      table.Topics,
		}
		componentJSON, err := componentJSONText(baseDir, spec, comp, table)
		if err != nil {
			return nil, fmt.Errorf("component %s: %w", comp.Name, err)
		}
		row.ComponentJS = componentJSON
		if opts.Language == LanguageGo {
			if text, ok, err := goComponentOverlayText(baseDir, spec.Overlays, comp.Name, "goFilterFile"); err != nil {
				return nil, fmt.Errorf("component %s: %w", comp.Name, err)
			} else if ok {
				row.GoFilterOverlay = text
				row.GoFilterOverlaySet = true
			}
			if text, ok, err := goComponentOverlayText(baseDir, spec.Overlays, comp.Name, "goModelFile"); err != nil {
				return nil, fmt.Errorf("component %s: %w", comp.Name, err)
			} else if ok {
				row.GoModelOverlay = text
				row.GoModelOverlaySet = true
			}
		}
		model.Components = append(model.Components, row)
		if model.Project.DefaultComp == "" {
			model.Project.DefaultComp = row.Name
		}
		if crud := crudSet(comp.Public); crud != "" {
			acl := aclForComponent(row, crud)
			model.PublicACL = append(model.PublicACL, acl)
		}
		roleNames := slices.Sorted(maps.Keys(comp.Roles))
		for _, roleName := range roleNames {
			crud := crudSet(comp.Roles[roleName])
			if crud == "" {
				continue
			}
			role := rolesByName[roleName]
			acl := aclForComponent(row, crud)
			acl.RoleID = role.ID
			acl.RoleName = role.Name
			acl.FieldID = role.FieldID
			model.RoleACL = append(model.RoleACL, acl)
		}
	}
	if model.Project.DefaultComp == "" {
		return nil, fmt.Errorf("project.default.component is required")
	}
	model.Other = buildOtherRows(model, tablesByID)
	return model, nil
}

func specText(baseDir, inline, path string) (string, error) {
	if strings.TrimSpace(inline) != "" {
		return inline, nil
	}
	if strings.TrimSpace(path) == "" {
		return "", fmt.Errorf("missing inline text or file path")
	}
	data, err := os.ReadFile(resolveSpecPath(baseDir, path))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func componentJSONText(baseDir string, spec *Spec, comp Component, table tableRow) (string, error) {
	if len(comp.ComponentJSON) > 0 {
		if err := validateComponentJSONBytes(comp.Name, "componentJson", comp.ComponentJSON); err != nil {
			return "", err
		}
		return string(comp.ComponentJSON) + "\n", nil
	}
	if strings.TrimSpace(comp.ComponentJSONFile) != "" {
		data, err := os.ReadFile(resolveSpecPath(baseDir, comp.ComponentJSONFile))
		if err != nil {
			return "", err
		}
		if err := validateComponentJSONBytes(comp.Name, "componentJsonFile "+comp.ComponentJSONFile, data); err != nil {
			return "", err
		}
		return string(data), nil
	}
	text := mustJSON(componentJSONHash(spec, comp, table))
	if err := validateComponentJSONBytes(comp.Name, "generated component JSON", []byte(text)); err != nil {
		return "", err
	}
	return text, nil
}

func goComponentOverlayText(baseDir string, overlays map[string]any, componentName, key string) (string, bool, error) {
	if len(overlays) == 0 {
		return "", false, nil
	}
	componentsRaw, ok := overlays["components"]
	if !ok {
		return "", false, nil
	}
	components, ok := componentsRaw.(map[string]any)
	if !ok {
		return "", false, fmt.Errorf("overlays.components must be an object")
	}
	componentRaw, ok := components[componentName]
	if !ok {
		return "", false, nil
	}
	componentOverlays, ok := componentRaw.(map[string]any)
	if !ok {
		return "", false, fmt.Errorf("overlays.components.%s must be an object", componentName)
	}
	pathRaw, ok := componentOverlays[key]
	if !ok {
		return "", false, nil
	}
	path, ok := pathRaw.(string)
	if !ok {
		return "", false, fmt.Errorf("overlays.components.%s.%s must be a string", componentName, key)
	}
	if strings.TrimSpace(path) == "" {
		return "", false, nil
	}
	data, err := os.ReadFile(resolveSpecPath(baseDir, path))
	if err != nil {
		return "", false, fmt.Errorf("%s %s: %w", key, path, err)
	}
	return string(data), true, nil
}

func validateComponentJSONBytes(componentName, label string, data []byte) error {
	var value any
	if err := json.Unmarshal(data, &value); err != nil {
		return fmt.Errorf("invalid component JSON override for %s (%s): %w", firstNonEmpty(componentName, "(unknown)"), label, err)
	}
	return validateComponentJSONValue(componentName, label, value)
}

func validateComponentJSONValue(componentName, label string, value any) error {
	name := firstNonEmpty(componentName, "(unknown)")
	var errors []string
	jsonObject, ok := value.(map[string]any)
	if !ok {
		errors = append(errors, "must be a JSON object")
	} else {
		actions, ok := requireJSONObject(jsonObject, "actions", &errors)
		requireJSONString(jsonObject, "current_table", &errors)
		requireJSONString(jsonObject, "current_key", &errors)
		for _, key := range []string{"edit_pars", "insert_pars", "update_pars", "topics_pars"} {
			requireJSONStringArray(jsonObject, key, &errors)
		}
		if ok {
			validateComponentActions(actions, &errors)
		}
	}
	if len(errors) > 0 {
		return fmt.Errorf("invalid component JSON for %s (%s): %s", name, label, strings.Join(errors, "; "))
	}
	return nil
}

func requireJSONObject(jsonObject map[string]any, key string, errors *[]string) (map[string]any, bool) {
	value, ok := jsonObject[key]
	if !ok {
		*errors = append(*errors, key+" is required")
		return nil, false
	}
	out, ok := value.(map[string]any)
	if !ok {
		*errors = append(*errors, key+" must be an object")
		return nil, false
	}
	return out, true
}

func requireJSONString(jsonObject map[string]any, key string, errors *[]string) {
	value, ok := jsonObject[key]
	if !ok {
		*errors = append(*errors, key+" is required")
		return
	}
	if _, ok := value.(string); !ok {
		*errors = append(*errors, key+" must be a string")
	}
}

func requireJSONStringArray(jsonObject map[string]any, key string, errors *[]string) {
	value, ok := jsonObject[key]
	if !ok {
		*errors = append(*errors, key+" is required")
		return
	}
	items, ok := value.([]any)
	if !ok {
		*errors = append(*errors, key+" must be an array")
		return
	}
	for i, item := range items {
		if _, ok := item.(string); !ok {
			*errors = append(*errors, fmt.Sprintf("%s[%d] must be a string", key, i))
		}
	}
}

func validateComponentActions(actions map[string]any, errors *[]string) {
	names := slices.Sorted(maps.Keys(actions))
	for _, name := range names {
		action, ok := actions[name].(map[string]any)
		if !ok {
			*errors = append(*errors, "actions."+name+" must be an object")
			continue
		}
		for _, key := range []string{"groups", "options"} {
			value, ok := action[key]
			if !ok {
				continue
			}
			items, ok := value.([]any)
			if !ok {
				*errors = append(*errors, "actions."+name+"."+key+" must be an array")
				continue
			}
			for i, item := range items {
				if _, ok := item.(string); !ok {
					*errors = append(*errors, fmt.Sprintf("actions.%s.%s[%d] must be a string", name, key, i))
				}
			}
		}
	}
}

func resolveSpecPath(baseDir, path string) string {
	if filepath.IsAbs(path) {
		return path
	}
	if _, err := os.Stat(filepath.Join(baseDir, path)); err == nil {
		return filepath.Join(baseDir, path)
	}
	return path
}

func componentJSONHash(spec *Spec, comp Component, table tableRow) map[string]any {
	actions := map[string]map[string]any{}
	for _, action := range []string{"startnew", "insert", "edit", "update", "delete", "topics"} {
		actions[action] = map[string]any{}
	}
	for _, action := range comp.Public {
		if _, ok := actions[action]; ok {
			actions[action]["groups"] = []string{spec.Project.PublicRole}
		}
	}
	roleNames := slices.Sorted(maps.Keys(comp.Roles))
	for _, role := range roleNames {
		for _, action := range comp.Roles[role] {
			if _, ok := actions[action]; ok {
				groups, _ := actions[action]["groups"].([]string)
				actions[action]["groups"] = append(groups, role)
			}
		}
	}
	if _, ok := actions["startnew"]["groups"]; ok {
		actions["startnew"]["options"] = []string{"no_db", "no_method"}
	}
	out := map[string]any{
		"actions":       actions,
		"current_table": comp.Table,
		"current_key":   table.Key,
		"edit_pars":     table.Edit,
		"insert_pars":   table.Insert,
		"update_pars":   table.Update,
		"topics_pars":   table.Topics,
	}
	if table.AutoKey != "" {
		out["current_id_auto"] = table.AutoKey
	}
	return out
}

func aclForComponent(comp componentRow, crud string) aclRow {
	return aclRow{
		ComponentID:   comp.ID,
		ComponentName: comp.Name,
		CRUD:          crud,
		CurrentKey:    comp.Key,
		Insert:        comp.Insert,
		Edit:          comp.Edit,
		Update:        comp.Update,
		Topics:        comp.Topics,
	}
}

func buildOtherRows(model *generationModel, tablesByID map[int]tableRow) otherRows {
	var other otherRows
	for _, acl := range model.PublicACL {
		other.PublicLanding = append(other.PublicLanding, landingRow{Component: acl.ComponentName, Action: landingAction(acl.CRUD, true)})
	}
	for _, comp := range model.Components {
		other.AllComponents = append(other.AllComponents, componentListRow{Name: comp.Name})
	}
	for _, acl := range model.RoleACL {
		var role roleRow
		for _, candidate := range model.Roles {
			if candidate.ID == acl.RoleID {
				role = candidate
				break
			}
		}
		if role.Name == "" || role.Name == "a" {
			continue
		}
		roleTable := tablesByID[role.TableID]
		var comp componentRow
		for _, candidate := range model.Components {
			if candidate.ID == acl.ComponentID {
				comp = candidate
				break
			}
		}
		has := crudMap(acl.CRUD)
		level, action := 0, ""
		if role.TableID != 0 && role.TableID == comp.TableID && (has["topics"] || has["startnew"] || has["edit"]) {
			level = 1
			action = "topics"
			if has["edit"] {
				action = "edit"
			} else if has["startnew"] && !has["topics"] {
				action = "startnew"
			}
		} else if acl.InKey != "" && acl.InKey == roleTable.Key && (has["topics"] || has["startnew"]) {
			level = 2
			action = "topics"
			if !has["topics"] {
				action = "startnew"
			}
		} else if acl.InKey == "" && has["topics"] {
			level = 3
			action = "topics"
		}
		if level != 0 {
			other.RoleLanding = append(other.RoleLanding, roleLandingRow{
				RoleID: role.ID, RoleName: role.Name, DefaultComponent: role.DefaultComponent,
				DefaultAction: role.DefaultAction, Component: comp.Name, Level: level, Action: action,
				IsEdit: has["edit"], IsTopics: has["topics"], IsStartNew: has["startnew"],
			})
		}
	}
	slices.SortFunc(other.RoleLanding, func(a, b roleLandingRow) int {
		return cmp.Or(
			cmp.Compare(a.Component, b.Component),
			cmp.Compare(a.Level, b.Level),
		)
	})
	return other
}

func landingAction(crud string, public bool) string {
	has := crudMap(crud)
	if has["topics"] {
		return "topics"
	}
	if has["startnew"] {
		return "startnew"
	}
	if public {
		return ""
	}
	if has["edit"] {
		return "edit"
	}
	return ""
}

func crudSet(actions []string) string {
	allowed := map[string]bool{"startnew": true, "insert": true, "edit": true, "update": true, "delete": true, "topics": true}
	var out []string
	for _, action := range actions {
		if allowed[action] {
			out = append(out, action)
		}
	}
	return strings.Join(out, ",")
}

func crudMap(crud string) map[string]bool {
	out := map[string]bool{}
	for _, part := range strings.Split(crud, ",") {
		if part != "" {
			out[part] = true
		}
	}
	return out
}

func mustJSON(v any) string {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		panic(err)
	}
	return string(data) + "\n"
}

func deterministicHex(opts GenerateOptions, n int) string {
	if opts.Secret != "" {
		return opts.Secret
	}
	if opts.Deterministic {
		return strings.Repeat("0", n)
	}
	buf := make([]byte, (n+1)/2)
	if _, err := rand.Read(buf); err != nil {
		return strings.Repeat("0", n)
	}
	return hex.EncodeToString(buf)[:n]
}

func cloneIntrospection(in *Introspection) *Introspection {
	if in == nil {
		return nil
	}
	out := &Introspection{
		Source:         in.Source,
		Warnings:       slices.Clone(in.Warnings),
		WarningDetails: slices.Clone(in.WarningDetails),
	}
	if out.Warnings == nil {
		out.Warnings = []string{}
	}
	if out.WarningDetails == nil {
		out.WarningDetails = []xmeta.Diagnostic{}
	}
	return out
}
