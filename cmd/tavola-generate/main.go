package main

import (
	"database/sql"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
	_ "github.com/mattn/go-sqlite3"

	"github.com/genelet/sqlmeta/xmeta"
	"github.com/guruperl/tavola"
	"google.golang.org/protobuf/encoding/protojson"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	var (
		specPath      string
		metaPath      string
		expandedPath  string
		driver        string
		dsn           string
		database      string
		schemasCSV    string
		overridesPath string
		outDir        string
		tarPath       string
		replace       bool
		dryRun        bool
		lang          string
		project       string
		script        string
		publicRole    string
		dsNickname    string
		dsPath        string
		dbHost        string
		dbPort        string
		dbUser        string
		dbPassword    string
		authTable     string
		authID        string
		authLogin     string
		authPassword  string
		authFirst     string
		authLast      string
		authRole      string
		fallbackAll   bool
		deterministic bool
	)
	flag.StringVar(&specPath, "spec", "", "compatibility Tavola JSON spec path")
	flag.StringVar(&metaPath, "meta", "", "sqlmeta MetaDatabase file (.json, .textpb, .pb)")
	flag.StringVar(&expandedPath, "expanded-app", "", "sqlmeta ExpandedAppSpec file (.json)")
	flag.StringVar(&driver, "driver", "", "database driver for live introspection: mysql, postgres, sqlite")
	flag.StringVar(&dsn, "dsn", "", "database/sql DSN for live introspection")
	flag.StringVar(&database, "database", "", "database name")
	flag.StringVar(&schemasCSV, "schemas", "", "comma-separated schemas for postgres introspection")
	flag.StringVar(&overridesPath, "relationship-overrides", "", "sqlmeta SchemaRelationshipOverrides file")
	flag.StringVar(&outDir, "out", "", "write generated files into directory")
	flag.StringVar(&tarPath, "tar", "", "write generated tar archive")
	flag.BoolVar(&replace, "replace", false, "replace --out directory when it exists")
	flag.BoolVar(&dryRun, "dry-run", false, "validate inputs and summarize generation without writing")
	flag.StringVar(&lang, "lang", "php", "output language: php, perl, go")
	flag.StringVar(&project, "project", "", "project/app name")
	flag.StringVar(&script, "script", "", "generated script route")
	flag.StringVar(&publicRole, "public-role", "p", "public role name")
	flag.StringVar(&dsNickname, "ds-nickname", "", "datasource nickname")
	flag.StringVar(&dsPath, "ds-path", "", "sqlite datasource path")
	flag.StringVar(&dbHost, "db-host", "", "generated datasource host")
	flag.StringVar(&dbPort, "db-port", "", "generated datasource port")
	flag.StringVar(&dbUser, "db-user", "", "generated datasource user")
	flag.StringVar(&dbPassword, "db-password", "", "generated datasource password")
	flag.StringVar(&authTable, "auth-table", "", "auth user table")
	flag.StringVar(&authID, "auth-id", "", "auth user id column")
	flag.StringVar(&authLogin, "auth-login", "", "auth login column")
	flag.StringVar(&authPassword, "auth-password", "", "auth password column")
	flag.StringVar(&authFirst, "auth-firstname", "", "auth firstname column")
	flag.StringVar(&authLast, "auth-lastname", "", "auth lastname column")
	flag.StringVar(&authRole, "auth-role", "u", "protected auth role name")
	flag.BoolVar(&fallbackAll, "fallback-all-tables", false, "grant auth role access to all tables")
	flag.BoolVar(&deterministic, "deterministic", false, "use deterministic generated secrets")
	flag.Parse()

	if !dryRun && outDir == "" && tarPath == "" {
		return fmt.Errorf("provide --out or --tar")
	}
	opts := tavola.GenerateOptions{
		Language:           tavola.Language(strings.ToLower(lang)),
		Project:            project,
		Script:             script,
		PublicRole:         publicRole,
		DatasourceType:     driver,
		DatasourceNickname: dsNickname,
		DatasourceDatabase: database,
		DatasourceHost:     dbHost,
		DatasourcePort:     dbPort,
		DatasourceUser:     dbUser,
		DatasourcePassword: dbPassword,
		DatasourcePath:     dsPath,
		SpecPath:           specPath,
		Deterministic:      deterministic,
	}

	var archive *tavola.Archive
	var err error
	switch {
	case specPath != "":
		spec, err := tavola.LoadTavolaSpecFile(specPath)
		if err != nil {
			return err
		}
		archive, err = tavola.GenerateFromTavolaSpec(spec, opts)
	case expandedPath != "":
		if metaPath == "" {
			return fmt.Errorf("--expanded-app requires --meta")
		}
		meta, err := xmeta.LoadMetaDatabaseFromFile(metaPath)
		if err != nil {
			return err
		}
		app, err := loadExpandedApp(expandedPath)
		if err != nil {
			return err
		}
		archive, err = tavola.GenerateFromExpandedApp(meta, app, opts)
	case metaPath != "":
		meta, err := xmeta.LoadMetaDatabaseFromFile(metaPath)
		if err != nil {
			return err
		}
		sqlOpts, err := sqlmetaOptions(opts, authTable, authID, authLogin, authPassword, authFirst, authLast, authRole, fallbackAll, overridesPath)
		if err != nil {
			return err
		}
		archive, err = tavola.GenerateFromSQLMeta(meta, sqlOpts)
	case driver != "" && dsn != "":
		meta, err := introspect(driver, dsn, database, splitCSV(schemasCSV))
		if err != nil {
			return err
		}
		sqlOpts, err := sqlmetaOptions(opts, authTable, authID, authLogin, authPassword, authFirst, authLast, authRole, fallbackAll, overridesPath)
		if err != nil {
			return err
		}
		archive, err = tavola.GenerateFromSQLMeta(meta, sqlOpts)
	default:
		return fmt.Errorf("provide --spec, --meta, --expanded-app with --meta, or --driver and --dsn")
	}
	if err != nil {
		return err
	}
	if dryRun {
		fmt.Printf("Dry run: generated %s archive with %d files\n", opts.Language, len(archive.Files()))
		return nil
	}
	if tarPath != "" {
		if err := archive.WriteTar(tarPath); err != nil {
			return err
		}
	}
	if outDir != "" {
		if _, err := os.Stat(outDir); err == nil {
			if !replace {
				return fmt.Errorf("output path exists. Use --replace to overwrite: %s", outDir)
			}
			if err := os.RemoveAll(outDir); err != nil {
				return err
			}
		} else if !os.IsNotExist(err) {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(outDir), 0755); err != nil {
			return err
		}
		if err := archive.WriteDir(outDir); err != nil {
			return err
		}
	}
	return nil
}

func sqlmetaOptions(opts tavola.GenerateOptions, authTable, authID, authLogin, authPassword, authFirst, authLast, authRole string, fallbackAll bool, overridesPath string) (tavola.SQLMetaGenerateOptions, error) {
	out := tavola.SQLMetaGenerateOptions{GenerateOptions: opts}
	if authTable != "" || authID != "" || authLogin != "" || authPassword != "" {
		missing := []string{}
		if authTable == "" {
			missing = append(missing, "--auth-table")
		}
		if authID == "" {
			missing = append(missing, "--auth-id")
		}
		if authLogin == "" {
			missing = append(missing, "--auth-login")
		}
		if authPassword == "" {
			missing = append(missing, "--auth-password")
		}
		if len(missing) > 0 {
			return out, fmt.Errorf("partial auth config; missing %s", strings.Join(missing, ", "))
		}
		out.AppSpec.Auth = &xmeta.AuthBinding{
			UserTable:       xmeta.ObjectNameFromString(authTable),
			UserIDColumn:    authID,
			LoginColumn:     authLogin,
			PasswordColumn:  authPassword,
			FirstNameColumn: authFirst,
			LastNameColumn:  authLast,
		}
		out.AppSpec.RoleName = authRole
		out.AppSpec.FallbackAllTables = fallbackAll
	}
	if overridesPath != "" {
		overrides, err := xmeta.LoadSchemaRelationshipOverridesFromFile(overridesPath)
		if err != nil {
			return out, err
		}
		out.AppSpec.SchemaOverrides = overrides
	}
	return out, nil
}

func introspect(driver, dsn, database string, schemas []string) (*xmeta.MetaDatabase, error) {
	sqlDriver := strings.ToLower(driver)
	if sqlDriver == "sqlite" || sqlDriver == "sqlite3" {
		sqlDriver = "sqlite3"
	} else if sqlDriver == "postgresql" || sqlDriver == "pgsql" {
		sqlDriver = "postgres"
	}
	db, err := sql.Open(sqlDriver, dsn)
	if err != nil {
		return nil, err
	}
	defer db.Close()
	return xmeta.LoadMetaDatabase(db, xmeta.LoadOptions{Driver: driver, Database: database, Schemas: schemas})
}

func loadExpandedApp(path string) (*xmeta.ExpandedAppSpec, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var app xmeta.ExpandedAppSpec
	if err := protojson.Unmarshal(data, &app); err != nil {
		return nil, err
	}
	return &app, nil
}

func splitCSV(value string) []string {
	var out []string
	for _, part := range strings.Split(value, ",") {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}
