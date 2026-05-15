# Tabilet

Tabilet is a headless generator for database-backed web projects and API
services. It builds on the Genelet framework and models an application as
projects, roles, database tables, components, actions, and templates.

Generated projects can expose REST-style endpoints and browser views from the
same component definitions. The old hosted Tabilet builder UI is not part of
`main`; keep using the `ui` branch for that historical web app.

## Repository Layout

- `script/` contains generator and metadata compatibility commands.
- `assets/` contains static assets copied into generated applications.
- `conf/` contains application configuration and database seed SQL.
- `lib/Tabilet/Generator/` contains language-specific generators.
- `lib/Tabilet/Project/` contains JSON spec loading and export orchestration.
- `lib/Tabilet/Template/` contains generated-app UI templates.
- `specs/` contains JSON project specs and fixture SQL.

## Requirements

- Perl 5
- Genelet framework modules available on `@INC`
- DBI and the database driver for the configured database
- JSON and Archive::Tar
- Template Toolkit and XML::LibXML for generated-app template output
- A MySQL or PostgreSQL metadata database only when using the compatibility
  importer/exporter path

For local framework tests, the sibling Genelet repository can run its default
SQLite-backed test suite without a service database.

## Configuration

`conf/config.json` provides generator defaults and the metadata DB connection
for compatibility import/export. Direct JSON generation can run without a
metadata database, but DB-backed commands require:

```text
TABILET_DB_USER
TABILET_DB_PASS
```

Generated application specs can still contain their own datasource placeholders,
such as `${JENNY_DB_USER}` and `${JENNY_DB_PASSWORD}`.

## JSON Project Specs

Tabilet can generate an application directly from a JSON project spec. The JSON
file is the source of truth for the records that the old UI collected: owner,
project, datasource, tables, procedures, roles, components, action access,
landing defaults, and optional custom generated-code overlays.

Start from the template, then edit the copied spec:

```bash
cp specs/project.template.json specs/my.project.json
```

Validate a spec without writing files:

```bash
script/generate-project --lang php --spec specs/project.template.json --dry-run
```

Generate a PHP app directly from JSON:

```bash
script/generate-project \
  --lang php \
  --spec specs/jenny.project.json \
  --out ../jenny \
  --replace
```

Use `--lang perl` for Perl output and `--tar PATH` instead of `--out PATH` to
write an archive without extracting it. Generated app web UI files are included
by default; add `--no-web-ui` to generate backend/API files without `views/`,
Vue files, `www/app.html`, `www/index.html`, or `www/genelet.js`.

## Metadata DB Compatibility

The metadata database path is still available for compatibility and migration
checks.

Initialize the Tabilet metadata database:

```bash
mysql -u root tabilet < conf/init.sql
```

Import or replace a project in the metadata database:

```bash
TABILET_DB_USER=... TABILET_DB_PASS=... \
script/import-project-spec \
  --config conf/config.json \
  --spec specs/jenny.project.json \
  --replace
```

The importer writes Tabilet metadata records only. The generated app still has
its own runtime database, initialized from the exported app's `conf/init.sql`.
After import, export the generated app from the populated Tabilet records:

```bash
TABILET_DB_USER=... TABILET_DB_PASS=... \
script/export-project \
  --config conf/config.json \
  --owner jenny \
  --out ../jenny \
  --replace
```

Use `--tar PATH` instead of `--out PATH` to write an archive without extracting
it. The direct generator and metadata exporter are headless and do not require
the Tabilet web UI, CGI entrypoints, or browser workflow.

Custom generated-code files should be kept as explicit overlays referenced by
the JSON spec. See [Custom Code Overlays](docs/custom-code-overlays.md).

## Development Checks

Compile the application modules and entrypoints:

```bash
find lib -name '*.pm' | sort | while read -r f; do
  perl -Ilib -I../perl -c "$f" >/dev/null || exit 1
done

perl -Ilib -I../perl -c script/import-project-spec
perl -Ilib -I../perl -c script/export-project
perl -Ilib -I../perl -c script/generate-project
```

Run the Genelet framework tests from this checkout when the sibling `../perl`
repository is present:

```bash
prove -I../perl ../perl/Genelet/Test/*.t
```
