# Tavola

Tavola is a headless generator for database-backed web projects and API
services. It builds on the Genelet framework and models an application as
projects, roles, database tables, components, actions, and templates.

Tavola converts user intent into a deployable API-backed application and
publishes the generated app's API as OpenAPI.

Tavola is app-spec native: roles, login fields, component actions, database
metadata, generated runtime config, API docs, and OpenAPI are all derived from
the same JSON project spec.

Generated projects can expose REST-style endpoints and browser views from the
same component definitions. The old hosted Tavola builder UI is historical and
is not part of Tavola's `main`; keep using the `ui` branch for that web app.

## Tavola or golet/genesis

Use Tavola when you want a reviewed JSON project spec to produce a deployable
PHP, Perl, or Go application archive with generated runtime config and API docs.
Use `golet/genesis` when a Go service should introspect a live database and
construct a Genelet controller in process without writing a generated app tree.

| Need | Use |
| --- | --- |
| Reviewed source-of-truth JSON, code archive, repeatable regeneration | Tavola |
| Embedded Go runtime config from a live DB schema | `golet/genesis` |
| PHP or Perl output | Tavola |
| Standalone generated Go/Genelet service | Tavola `--lang go` |

## Repository Layout

- `cmd/tavola-generate/` contains the Go generator CLI.
- `script/` contains compatibility wrappers and smoke checks.
- `assets/` contains static assets copied into generated applications.
- `conf/` contains application configuration and database seed SQL.
- `specs/` contains JSON project specs and fixture SQL.

## Requirements

- Go 1.25+
- JSON
- PDO and the PDO driver for generated PHP apps, when running generated PHP
- Genelet dependencies for generated Perl/Go apps, when running those outputs
- Go 1.22+ for generated Go apps

For local framework tests, the sibling Genelet repository can run its default
SQLite-backed test suite without a service database.

## Configuration

`conf/config.json` is retained for legacy runtime defaults and fixtures. The Go
generator reads the project spec directly and does not require a Tavola
metadata database.

Generated application specs can still contain their own datasource placeholders,
such as `${APP_DB_USER}` and `${APP_DB_PASSWORD}`.
Generated runtime datasources can target MySQL, PostgreSQL, or SQLite when the
spec supplies matching SQL and the generated app has the needed DBI/PDO driver.

## JSON Project Specs

Tavola can generate an application directly from a JSON project spec. The JSON
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

`jenny` is used here as the generated app name and output path. It marks an app
produced by Tavola; it is not a Tavola subsystem or package.

Use `--lang perl` for Perl output emitted by the Go generator, `--lang go` for
Go/Genelet output, and `--tar PATH` instead of `--out PATH` to write an archive
without extracting it.
The legacy Perl generator has been removed; `script/generate-project` now
delegates to the Go `cmd/tavola-generate` implementation. The compatibility
`--no-web-ui` flag is accepted by the wrapper, but the Go generator currently
emits backend/API archives.

## Generated Archive Contents

The generator writes a complete application archive. The common files are:

- `conf/config.json` contains generated runtime configuration for the app.
- `conf/init.sql` contains table and stored procedure SQL from the project
  spec.
- `api.json` contains a machine-readable Tavola API manifest with roles,
  login requirements, components, actions, parameters, and example endpoints.
- `openapi.json` contains an OpenAPI 3.0 document derived from `api.json` for
  tooling that expects OpenAPI. Tavola-specific action details are preserved
  in `x-tavola-*` extensions.
- `docs/api.md` contains generated API documentation derived from `api.json`.
- `docs/api.schema.json` contains the JSON Schema used to validate `api.json`.
- `logs/debug.log` is an empty log file placeholder.
- Component `component.json` files describe generated actions, roles, request
  parameters, and table metadata.

PHP archives include `composer.json`, `www/app.php`, project classes under
`src/`, and component classes under `src/<component>/`. Perl archives include
`script/app`, project modules under `lib/<Project>/`, and component modules
under `lib/<Project>/<Component>/`. Go archives include `go.mod`, `README.md`,
a `cmd/<project>/main.go` entrypoint, app registration under `internal/app/`,
and component packages under `internal/<component>/`.

The old Perl generator's Vue/browser template output has been removed. The
current Go generator emits backend/API archives plus runtime template paths in
`conf/config.json`; richer generated browser templates can be added back in the
Go emitter when needed.

Run the offline smoke harness to generate both language targets into a
temporary directory and verify the backend/API archive layout:

```bash
script/smoke-generated-project --spec specs/project.template.json --lang all --no-web-ui
```

Run the focused Go CRUD route smoke with the SQLite fixture:

```bash
script/smoke-generated-project --spec specs/go-smoke.project.json --lang go --web-ui
```

## Generated Endpoint Pattern

Generated apps use one front controller and route requests by role, response
tag, component, and action:

```text
<script>/<role>/<tag>/<component>?action=<action>
```

For PHP output, `<script>` is usually `www/app.php`. For Perl output, the
generated executable is `script/app`; configure the web server so the spec's
`project.script` URL is handled by that executable. The Jenny spec uses
`/jenny/app.php` to identify the generated app, so a Perl Jenny deployment can
still expose:

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

The removed Perl generator used to emit a Vue shell and copied browser assets.
The Go generator currently focuses on backend/API output while keeping the same
JSON and HTML endpoint pattern in the generated app contract.

## Metadata DB Compatibility

The old metadata DB import/export generator path was removed. Tavola JSON is
still supported as a compatibility input and fixture format, but archive
generation now goes through the Go package and `cmd/tavola-generate`.

Custom generated-code files should be kept as explicit overlays referenced by
the JSON spec. See [Custom Code Overlays](docs/custom-code-overlays.md).

## Development Checks

Run the Go generator and compatibility regression tests:

```bash
GOWORK=off go test ./...
```

Run generated-output smoke checks:

```bash
script/smoke-generated-project --spec specs/project.template.json --lang all --no-web-ui
script/smoke-sqlite-init
```

For release gates and the module-path migration rule, see
[Release Checklist](docs/release-checklist.md).
