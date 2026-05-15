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
such as `${APP_DB_USER}` and `${APP_DB_PASSWORD}`.

## JSON Project Specs

Tabilet can generate an application directly from a JSON project spec. The JSON
file is the source of truth for the records that the old UI collected: owner,
project, datasource, tables, procedures, roles, components, action access,
landing defaults, and optional custom generated-code overlays.

For the spec format, role login setup, and component permission rules, see
[Project Spec Reference](docs/project-spec.md).

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

## Generated Archive Contents

The generator writes a complete application archive. The common files are:

- `conf/config.json` contains generated runtime configuration for the app.
- `conf/init.sql` contains table and stored procedure SQL from the project
  spec.
- `api.json` contains a machine-readable Tabilet API manifest with roles,
  login requirements, components, actions, parameters, and example endpoints.
- `docs/api.md` contains generated API documentation derived from `api.json`.
- `logs/debug.log` is an empty log file placeholder.
- Component `component.json` files describe generated actions, roles, request
  parameters, and table metadata.

PHP archives include `composer.json`, `www/app.php`, project classes under
`src/`, and component classes under `src/<component>/`. Perl archives include
`script/app`, project modules under `lib/<Project>/`, and component modules
under `lib/<Project>/<Component>/`.

When generated app web UI is enabled, the archive also includes:

- `views/` with server-rendered HTML templates for each role and component.
- `www/<role>/*.vue` and `www/<role>/<component>/*.vue` with Vue components.
- `www/app.html`, the browser app shell that loads Vue components.
- `www/index.html`, a generated route index for Twig and Vue entrypoints.
- `www/genelet.js`, the browser helper copied from `assets/genelet.js`.

These files are generated app UI, not the old hosted Tabilet builder UI. Use
`--no-web-ui` when you only want backend/API output.

Run the offline smoke harness to generate both language targets into a
temporary directory and verify the backend/API archive layout:

```bash
script/smoke-generated-project --spec specs/project.template.json --lang all --no-web-ui
```

## Generated Endpoint Pattern

Generated apps use one front controller and route requests by role, response
tag, component, and action:

```text
<script>/<role>/<tag>/<component>?action=<action>
```

For PHP output, `<script>` is usually `www/app.php`. For Perl output, the
generated executable is `script/app`; configure the web server so the spec's
`project.script` URL is handled by that executable. Jenny's spec uses
`/jenny/app.php`, so a Perl Jenny deployment can still expose:

```text
/jenny/app.php/p/json/car?action=topics
/jenny/app.php/a/html/car?action=edit&car_id=123
```

The JSON API uses the `json` tag:

```text
/app.php/p/json/widget?action=topics
/app.php/a/json/widget?action=edit&id=123
```

Server-rendered browser views use the `html` tag and the same role/component
action model:

```text
/app.php/p/html/widget?action=topics
/app.php/a/html/widget?action=startnew
```

`<role>` is the public role from `project.publicRole` or one of the named roles
in the spec. `<component>` is a generated component name. `<action>` is an
action allowed by that component's `component.json`, such as `topics`,
`startnew`, `insert`, `edit`, `update`, or `delete`.

The generated Vue shell at `www/app.html` uses hash routes such as
`/app.html#/p/widget?action=topics`, then calls the JSON endpoint through
`www/genelet.js`. API-only archives generated with `--no-web-ui` keep the same
JSON endpoint pattern but omit the browser shell, Vue components, and HTML
templates.

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
perl -Ilib -I../perl -c script/smoke-generated-project
```

Run the Genelet framework tests from this checkout when the sibling `../perl`
repository is present:

```bash
prove -I../perl ../perl/Genelet/Test/*.t
```
