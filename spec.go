package tavola

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/genelet/sqlmeta/xmeta"
)

// Spec is Tavola's compatibility JSON project spec. It remains supported as an
// input and fixture format, while direct sqlmeta inputs are the primary API.
type Spec struct {
	Version       int            `json:"version"`
	Owner         Owner          `json:"owner"`
	Project       Project        `json:"project"`
	Datasource    Datasource     `json:"datasource"`
	Schema        Schema         `json:"schema"`
	Roles         []Role         `json:"roles"`
	Components    []Component    `json:"components"`
	Overlays      map[string]any `json:"overlays"`
	Introspection *Introspection `json:"introspection,omitempty"`
	BaseDir       string         `json:"-"`
}

type Owner struct {
	Login  string `json:"login"`
	Email  string `json:"email"`
	TypeID int    `json:"typeid"`
}

type Project struct {
	Name       string         `json:"name"`
	Script     string         `json:"script"`
	PublicRole string         `json:"publicRole"`
	Default    ProjectDefault `json:"default"`
}

type ProjectDefault struct {
	Component string `json:"component"`
	Action    string `json:"action"`
}

type Datasource struct {
	Type     string `json:"type"`
	Nickname string `json:"nickname"`
	Database string `json:"database,omitempty"`
	Path     string `json:"path,omitempty"`
	Host     string `json:"host,omitempty"`
	Port     string `json:"port,omitempty"`
	User     string `json:"user,omitempty"`
	Password string `json:"password,omitempty"`
}

type Schema struct {
	Tables     []Table     `json:"tables"`
	Procedures []Procedure `json:"procedures"`
}

type Table struct {
	Name          string   `json:"name"`
	PrimaryKey    string   `json:"primaryKey"`
	AutoKey       string   `json:"autoKey,omitempty"`
	Statement     string   `json:"statement,omitempty"`
	StatementFile string   `json:"statementFile,omitempty"`
	Insert        []string `json:"insert"`
	Edit          []string `json:"edit"`
	Update        []string `json:"update"`
	Topics        []string `json:"topics"`
	Comment       string   `json:"comment,omitempty"`
}

type Procedure struct {
	Name          string `json:"name"`
	Table         string `json:"table,omitempty"`
	Statement     string `json:"statement,omitempty"`
	StatementFile string `json:"statementFile,omitempty"`
}

type Role struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Authen      string         `json:"authen"`
	IsAdmin     int            `json:"isAdmin"`
	IsAuto      int            `json:"isAuto"`
	Table       string         `json:"table,omitempty"`
	Default     ProjectDefault `json:"default"`
	Fields      RoleFields     `json:"fields"`
	Restriction string         `json:"restriction"`
}

type RoleFields struct {
	ID        string `json:"id"`
	Login     string `json:"login"`
	Password  string `json:"password"`
	FirstName string `json:"firstname,omitempty"`
	LastName  string `json:"lastname,omitempty"`
}

type Component struct {
	Name              string              `json:"name"`
	Description       string              `json:"description"`
	Table             string              `json:"table"`
	Public            []string            `json:"public,omitempty"`
	Roles             map[string][]string `json:"roles,omitempty"`
	ComponentJSON     json.RawMessage     `json:"componentJson,omitempty"`
	ComponentJSONFile string              `json:"componentJsonFile,omitempty"`
}

type Introspection struct {
	Source         string             `json:"source"`
	Warnings       []string           `json:"warnings,omitempty"`
	WarningDetails []xmeta.Diagnostic `json:"warningDetails,omitempty"`
}

type Language string

const (
	LanguagePHP  Language = "php"
	LanguagePerl Language = "perl"
	LanguageGo   Language = "go"
)

type GenerateOptions struct {
	Language Language
	WebUI    bool

	Project            string
	Script             string
	PublicRole         string
	OwnerLogin         string
	OwnerEmail         string
	OwnerTypeID        int
	DatasourceType     string
	DatasourceNickname string
	DatasourceDatabase string
	DatasourceHost     string
	DatasourcePort     string
	DatasourceUser     string
	DatasourcePassword string
	DatasourcePath     string
	SpecPath           string
	SpecBaseDir        string

	Deterministic bool
	Secret        string
}

type SQLMetaGenerateOptions struct {
	GenerateOptions
	AppSpec xmeta.AppSpecOptions
}

func GenerateFromSQLMeta(meta *xmeta.MetaDatabase, opts SQLMetaGenerateOptions) (*Archive, error) {
	if meta == nil {
		return nil, fmt.Errorf("metadata database is nil")
	}
	appOpts := opts.AppSpec
	if strings.TrimSpace(appOpts.Name) == "" {
		appOpts.Name = firstNonEmpty(opts.Project, meta.GetName())
	}
	if appOpts.DatasourceDriver == "" {
		appOpts.DatasourceDriver = firstNonEmpty(opts.DatasourceType, meta.GetOptions()["Driver"])
	}
	if appOpts.DatasourceDatabase == "" {
		appOpts.DatasourceDatabase = firstNonEmpty(opts.DatasourceDatabase, meta.GetName())
	}
	if appOpts.DatasourceName == "" {
		appOpts.DatasourceName = firstNonEmpty(opts.DatasourceNickname, meta.GetName())
	}
	app, err := xmeta.BuildDefaultAppSpec(meta, appOpts)
	if err != nil {
		return nil, err
	}
	expanded, diagnostics, err := xmeta.ExpandRoleScopesWithDiagnostics(meta, app)
	if err != nil {
		return nil, err
	}
	return generateFromExpandedApp(meta, expanded, diagnostics, opts.GenerateOptions)
}

func GenerateFromExpandedApp(meta *xmeta.MetaDatabase, app *xmeta.ExpandedAppSpec, opts GenerateOptions) (*Archive, error) {
	return generateFromExpandedApp(meta, app, nil, opts)
}

func GenerateFromExpandedAppWithDiagnostics(meta *xmeta.MetaDatabase, app *xmeta.ExpandedAppSpec, diagnostics []xmeta.Diagnostic, opts GenerateOptions) (*Archive, error) {
	return generateFromExpandedApp(meta, app, diagnostics, opts)
}

func generateFromExpandedApp(meta *xmeta.MetaDatabase, app *xmeta.ExpandedAppSpec, diagnostics []xmeta.Diagnostic, opts GenerateOptions) (*Archive, error) {
	spec, err := buildSpecFromExpandedApp(meta, app, diagnostics, opts)
	if err != nil {
		return nil, err
	}
	return GenerateFromTavolaSpec(spec, opts)
}

func GenerateFromTavolaSpec(spec *Spec, opts GenerateOptions) (*Archive, error) {
	if spec == nil {
		return nil, fmt.Errorf("tavola spec is nil")
	}
	if opts.SpecPath == "" && opts.SpecBaseDir == "" && spec.BaseDir != "" {
		opts.SpecBaseDir = spec.BaseDir
	}
	if err := validateSpec(spec); err != nil {
		return nil, err
	}
	model, err := buildGenerationModel(spec, opts)
	if err != nil {
		return nil, err
	}
	return emitArchive(model)
}

func LoadTavolaSpecJSON(data []byte) (*Spec, error) {
	var spec Spec
	if err := json.Unmarshal(data, &spec); err != nil {
		return nil, err
	}
	return &spec, nil
}

func LoadTavolaSpecFile(path string) (*Spec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	spec, err := LoadTavolaSpecJSON(data)
	if err != nil {
		return nil, err
	}
	spec.BaseDir = filepath.Dir(path)
	return spec, nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func specBaseDir(opts GenerateOptions) string {
	if opts.SpecBaseDir != "" {
		return opts.SpecBaseDir
	}
	if opts.SpecPath != "" {
		return filepath.Dir(opts.SpecPath)
	}
	return "."
}
