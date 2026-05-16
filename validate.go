package tavola

import (
	"fmt"
	"path/filepath"
	"strings"
)

func ValidateTavolaSpec(spec *Spec) error {
	if spec == nil {
		return fmt.Errorf("tavola spec is nil")
	}
	return validateSpec(spec)
}

func validateSpec(spec *Spec) error {
	if spec.Version != 1 {
		return fmt.Errorf("spec version must be 1")
	}
	if strings.TrimSpace(spec.Project.Name) == "" {
		return fmt.Errorf("project.name is required")
	}
	if err := validateArchiveName("project.name", spec.Project.Name); err != nil {
		return err
	}
	if strings.TrimSpace(spec.Project.PublicRole) == "" {
		return fmt.Errorf("project.publicRole is required")
	}
	if spec.Project.Default.Component == "" || spec.Project.Default.Action == "" {
		return fmt.Errorf("project.default.component and project.default.action are required")
	}
	if _, err := datasourceFamily(spec.Datasource.Type); err != nil {
		return err
	}
	if len(spec.Schema.Tables) == 0 {
		return fmt.Errorf("schema.tables must not be empty")
	}
	tables := map[string]bool{}
	for _, table := range spec.Schema.Tables {
		if strings.TrimSpace(table.Name) == "" || strings.TrimSpace(table.PrimaryKey) == "" {
			return fmt.Errorf("tables require name and primaryKey")
		}
		if strings.TrimSpace(table.Statement) == "" && strings.TrimSpace(table.StatementFile) == "" {
			return fmt.Errorf("table %s needs statement or statementFile", table.Name)
		}
		tables[table.Name] = true
	}
	for _, proc := range spec.Schema.Procedures {
		if strings.TrimSpace(proc.Name) == "" {
			return fmt.Errorf("procedures require name")
		}
		if strings.TrimSpace(proc.Statement) == "" && strings.TrimSpace(proc.StatementFile) == "" {
			return fmt.Errorf("procedure %s needs statement or statementFile", proc.Name)
		}
		if proc.Table != "" && !tables[proc.Table] {
			return fmt.Errorf("procedure %s references unknown table %s", proc.Name, proc.Table)
		}
	}
	roles := map[string]bool{}
	for _, role := range spec.Roles {
		if strings.TrimSpace(role.Name) == "" {
			return fmt.Errorf("roles require name")
		}
		if role.Table != "" && !tables[role.Table] {
			return fmt.Errorf("role %s references unknown table %s", role.Name, role.Table)
		}
		roles[role.Name] = true
	}
	for _, comp := range spec.Components {
		if strings.TrimSpace(comp.Name) == "" || strings.TrimSpace(comp.Table) == "" {
			return fmt.Errorf("components require name and table")
		}
		if err := validateArchiveName("component "+comp.Name, comp.Name); err != nil {
			return err
		}
		if !tables[comp.Table] {
			return fmt.Errorf("component %s references unknown table %s", comp.Name, comp.Table)
		}
		for role := range comp.Roles {
			if !roles[role] {
				return fmt.Errorf("component %s references unknown role %s", comp.Name, role)
			}
		}
	}
	return nil
}

func validateArchiveName(label, value string) error {
	if strings.Contains(value, "/") || strings.Contains(value, `\`) {
		return fmt.Errorf("%s must not contain path separators", label)
	}
	clean := filepath.ToSlash(filepath.Clean(value))
	if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return fmt.Errorf("%s must not be a relative path", label)
	}
	return nil
}

func datasourceFamily(value string) (string, error) {
	normalized := strings.ToLower(value)
	normalized = strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, normalized)
	switch normalized {
	case "mysql", "mariadb":
		return "mysql", nil
	case "postgres", "postgresql", "pgsql":
		return "postgresql", nil
	case "sqlite", "sqlite3":
		return "sqlite", nil
	default:
		return "", fmt.Errorf("unsupported datasource type %q", value)
	}
}
