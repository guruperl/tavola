package tavola

import (
	"fmt"
	"strings"
)

func emitGo(a *Archive, model *generationModel, manifest map[string]any) {
	module := "example.com/tavola/" + safePath(model.Project.Project)
	cmd := safePath(model.Project.Project)
	specs := goComponentSpecs(model.Components)
	a.AddString("go.mod", "module "+module+"\n\ngo 1.22\n\nrequire github.com/guruperl/genelet v0.1.1\n")
	a.AddString("README.md", goReadme(model, manifest))
	a.AddString("cmd/"+cmd+"/main.go", goMain(module))
	a.AddString("internal/app/app.go", goApp(module, model, specs))
	for _, comp := range model.Components {
		spec := specs[comp.Name]
		dir := spec.dir
		pkg := spec.pkg
		a.AddString("internal/"+dir+"/component.json", comp.ComponentJS)
		a.AddString("internal/"+dir+"/component.go", goComponentSupport(pkg))
		if comp.GoModelOverlaySet {
			a.AddString("internal/"+dir+"/model.go", comp.GoModelOverlay)
		} else {
			a.AddString("internal/"+dir+"/model.go", goComponentModel(pkg))
		}
		if comp.GoFilterOverlaySet {
			a.AddString("internal/"+dir+"/filter.go", comp.GoFilterOverlay)
		} else {
			a.AddString("internal/"+dir+"/filter.go", goComponentFilter(pkg))
		}
	}
}

func goReadme(model *generationModel, manifest map[string]any) string {
	return "# " + model.Project.Project + "\n\nGenerated Go/Genelet application from Tavola.\n\n## Setup\n\n```bash\ngo mod tidy\ngo test ./...\n```\n\nInitialize the database with `conf/init.sql`, then update `conf/config.json`.\n"
}

func goMain(module string) string {
	return `package main

import (
	"log"
	"net/http"

	"` + module + `/internal/app"
)

func main() {
	controller, cleanup, err := app.New(".")
	if err != nil {
		log.Fatal(err)
	}
	if cleanup != nil {
		defer cleanup()
	}
	log.Fatal(http.ListenAndServe(":"+controller.C.ServerPort, controller))
}
`
}

type goComponentSpec struct {
	dir string
	pkg string
}

func goComponentSpecs(components []componentRow) map[string]goComponentSpec {
	out := map[string]goComponentSpec{}
	seenDirs := map[string]int{}
	seenPkgs := map[string]int{}
	for _, comp := range components {
		dir := uniqueGoName(componentDir(comp.Name), seenDirs)
		pkg := uniqueGoName(safeIdent(comp.Name, "component"), seenPkgs)
		out[comp.Name] = goComponentSpec{dir: dir, pkg: pkg}
	}
	return out
}

func uniqueGoName(base string, seen map[string]int) string {
	if base == "" {
		base = "component"
	}
	seen[base]++
	if seen[base] == 1 {
		return base
	}
	return fmt.Sprintf("%s_%d", base, seen[base])
}

func goApp(module string, model *generationModel, specs map[string]goComponentSpec) string {
	var imports strings.Builder
	var registrations strings.Builder
	for _, comp := range model.Components {
		spec := specs[comp.Name]
		pkg := spec.pkg
		path := spec.dir
		imports.WriteString(fmt.Sprintf("\t%s %q\n", pkg, module+"/internal/"+path))
		registrations.WriteString(fmt.Sprintf("\tcontroller.ModelFactories[%q] = func() interface{} { return %s.NewModel() }\n", comp.Name, pkg))
		registrations.WriteString(fmt.Sprintf("\tcontroller.FilterFactories[%q] = func() interface{} { return %s.NewFilter() }\n", comp.Name, pkg))
	}
	return `package app

import (
	"database/sql"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/go-sql-driver/mysql"
	"github.com/guruperl/genelet"
` + imports.String() + `)

var envPattern = regexp.MustCompile(` + "`" + `\$\{([A-Z_][A-Z0-9_]*)\}` + "`" + `)

func New(root string) (*genelet.Controller, func() error, error) {
	config, err := LoadConfig(root)
	if err != nil {
		return nil, nil, err
	}
	db, err := config.OpenDB()
	if err != nil {
		return nil, nil, err
	}
	return NewController(config, db), db.Close, nil
}

func LoadConfig(root string) (*genelet.Config, error) {
	config, err := genelet.NewConfig(filepath.Join(root, "conf", "config.json"))
	if err != nil {
		return nil, err
	}
	if err := expandConnectArray(config.ConnectArray); err != nil {
		return nil, err
	}
	if err := normalizeConnectArray(config); err != nil {
		return nil, err
	}
	return config, nil
}

func NewController(config *genelet.Config, db *sql.DB) *genelet.Controller {
	controller := genelet.NewController(config, db)
` + registrations.String() + `	return controller
}

func expandConnectArray(values []string) error {
	for i, value := range values {
		expanded, err := expandEnvString(value)
		if err != nil {
			return err
		}
		values[i] = expanded
	}
	return nil
}

func expandEnvString(value string) (string, error) {
	var missing string
	out := envPattern.ReplaceAllStringFunc(value, func(match string) string {
		parts := envPattern.FindStringSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		found, ok := os.LookupEnv(parts[1])
		if !ok {
			missing = parts[1]
			return ""
		}
		return found
	})
	if missing != "" {
		return "", fmt.Errorf("missing required environment variable %s", missing)
	}
	return out, nil
}

func normalizeConnectArray(config *genelet.Config) error {
	if config == nil || len(config.ConnectArray) <= 2 {
		return nil
	}
	driver := genelet.NormalizeDriver(config.ConnectArray[0])
	if len(config.ConnectArray) != 6 {
		return fmt.Errorf("ConnectArray for %s must be [driver,user,password,host,port,database]", driver)
	}
	user := config.ConnectArray[1]
	password := config.ConnectArray[2]
	host := config.ConnectArray[3]
	port := config.ConnectArray[4]
	database := config.ConnectArray[5]
	switch driver {
	case "mysql":
		config.ConnectArray = []string{"mysql", (&mysql.Config{User: user, Passwd: password, Net: "tcp", Addr: net.JoinHostPort(host, port), DBName: database, AllowNativePasswords: true, ParseTime: true}).FormatDSN()}
	case "postgres":
		u := url.URL{Scheme: "postgres", User: url.UserPassword(user, password), Host: net.JoinHostPort(host, port), Path: "/" + strings.TrimPrefix(database, "/")}
		query := u.Query()
		query.Set("sslmode", "disable")
		u.RawQuery = query.Encode()
		config.ConnectArray = []string{"postgres", u.String()}
	default:
		return fmt.Errorf("unsupported structured ConnectArray driver %s", driver)
	}
	return nil
}
`
}

func goComponentSupport(pkg string) string {
	return `package ` + pkg + `

import (
	_ "embed"
	"encoding/json"

	"github.com/guruperl/genelet"
)

//go:embed component.json
var componentJSON []byte

func loadComponent() *genelet.Component {
	var component genelet.Component
	if err := json.Unmarshal(componentJSON, &component); err != nil {
		panic(err)
	}
	applyComponentDefaults(&component)
	if err := genelet.ValidateComponent(&component); err != nil {
		panic(err)
	}
	return &component
}

func applyComponentDefaults(component *genelet.Component) {
	if component.Sortby == "" { component.Sortby = "sortby" }
	if component.Sortreverse == "" { component.Sortreverse = "sortreverse" }
	if component.Pageno == "" { component.Pageno = "pageno" }
	if component.Totalno == "" { component.Totalno = "totalno" }
	if component.Rowcount == "" { component.Rowcount = "rowcount" }
	if component.Maxpageno == "" { component.Maxpageno = "maxpage" }
	if component.Fields == "" { component.Fields = "fields" }
	if component.Empties == "" { component.Empties = "empties" }
	if component.TotalForce == 0 { component.TotalForce = 1 }
}
`
}

func goComponentModel(pkg string) string {
	return `package ` + pkg + `

import (
	"net/url"

	"github.com/guruperl/genelet"
)

type Model struct { genelet.Model }

func NewModel() *Model {
	model := &Model{}
	model.Initialize(loadComponent())
	return model
}

func (model *Model) Topics(extra url.Values, nextextra url.Values) error { return model.Model.Topics(extra, nextextra) }
func (model *Model) Edit(extra url.Values, nextextra url.Values) error { return model.Model.Edit(extra, nextextra) }
func (model *Model) Insert(extra url.Values, nextextra url.Values) error { return model.Model.Insert(extra, nextextra) }
func (model *Model) Insupd(extra url.Values, nextextra url.Values) error { return model.Model.Insupd(extra, nextextra) }
func (model *Model) Update(extra url.Values, nextextra url.Values) error { return model.Model.Update(extra, nextextra) }
func (model *Model) Delete(extra url.Values, nextextra url.Values) error { return model.Model.Delete(extra, nextextra) }
`
}

func goComponentFilter(pkg string) string {
	return `package ` + pkg + `

import (
	"net/url"

	"github.com/guruperl/genelet"
)

type Filter struct { genelet.Filter }

func NewFilter() *Filter {
	filter := &Filter{}
	filter.Initialize(loadComponent())
	return filter
}

func (filter *Filter) Before(model *Model, extra url.Values, nextextra url.Values) error {
	return filter.Filter.Before(&model.Model, extra, nextextra)
}

func (filter *Filter) After(model *Model) error {
	return filter.Filter.After(&model.Model)
}
`
}
