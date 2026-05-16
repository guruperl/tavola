# Project Spec Reference

Tavola project specs describe the generated application. The JSON spec is the
source of truth for runtime config, database metadata, roles, components,
allowed actions, and optional generated-code overlays.

Start from `specs/project.template.json` for a minimal hand-written app, or
from `specs/supportdesk.project.json` for a reviewed sqlmeta-generated
source-of-truth example. The template contains a small app with a public role
`p`, a non-public login role `u`, a login table, one login procedure, and one
protected component.

For specs generated from an existing database, use sqlmeta's
`tavola-introspect` bridge. See [`sqlmeta-introspection.md`](sqlmeta-introspection.md).

## Top-Level Blocks

- `version`: spec format version. Use `1`.
- `owner`: metadata owner for compatibility import/export.
- `project`: generated app identity, URL prefix, public role, and default
  landing component/action.
- `datasource`: generated app runtime database connection values.
- `schema.tables`: database tables and the action parameter lists generated
  from them.
- `schema.procedures`: stored procedures used by generated SQL and role login.
- `roles`: non-public roles that require login.
- `components`: generated components, their backing tables, and public or
  role-protected actions.
- `overlays`: optional file replacements for generated project/component code.
- `introspection`: optional generator metadata for specs produced from database
  introspection.

## Owner And Project

`owner.login` is used by the metadata compatibility path and by default path
generation. `project.name` becomes the generated PHP namespace or Perl module
prefix. `project.script` is the public URL prefix handled by the generated app,
for example `/example/app.php`.

`project.publicRole` names the unauthenticated role. The conventional value is
`p`. `project.default` selects the component and action shown when the generated
browser UI starts.

## Datasource

`datasource` configures the generated app's runtime database, not the Tavola
metadata database. `type` supports `MySQL`, `PostgreSQL`, `SQLite`, or
`SQLite3`. MySQL and PostgreSQL datasources use `database`, `host`, `port`,
`user`, and `password`. SQLite datasources use `database` or `path` for the
database file and do not require host or credentials.

Values can use required environment placeholders:

```json
{
  "user": "${APP_DB_USER}",
  "password": "${APP_DB_PASSWORD}"
}
```

The generated app expands those placeholders at runtime. For SQLite, use a path
such as `data/app.sqlite` or `:memory:`.

PHP output can also override the runtime database at process startup with:

```text
TAVOLA_DB_DSN
TAVOLA_DB_USER
TAVOLA_DB_PASSWORD
```

Those variables are for the generated application's database. Use PDO DSNs such
as `mysql:host=...;dbname=...`,
`pgsql:host=...;dbname=...`, or `sqlite:data/app.sqlite`.

The metadata import/export commands use the separate `conf/config.json`
database settings. Table and procedure SQL in `schema` is copied into generated
`conf/init.sql` as provided, so use SQL syntax that matches the selected
runtime database.

## Tables And Actions

Each table needs:

- `name`: table name.
- `primaryKey`: primary key column.
- `statement` or `statementFile`: SQL used in generated `conf/init.sql`.
- `insert`, `edit`, `update`, `topics`: parameter lists used by generated
  component JSON and templates.

Use `autoKey` when the primary key is database-generated. Optional `fks`,
`uniques`, and `nons` are preserved for metadata compatibility.

## Login Roles

A non-public role is a `roles[]` entry. For database login, use `authen: "db"`.
The role must point at a login table and a procedure associated with that table.
That table and procedure are part of the generated app's runtime database, so
they must exist after you apply the generated `conf/init.sql`.

Minimal shape:

```json
{
  "name": "u",
  "authen": "db",
  "isAdmin": 0,
  "table": "app_user",
  "default": {
    "component": "item",
    "action": "topics"
  },
  "fields": {
    "id": "user_id",
    "login": "email",
    "password": "passwd",
    "firstname": "firstname",
    "lastname": "lastname"
  },
  "restriction": "status IN (\"Yes\")"
}
```

The login procedure is found by matching `schema.procedures[].table` to the
role's `table`. For the role above, the template uses:

```json
{
  "name": "proc_example_u",
  "table": "app_user",
  "statement": "CREATE PROCEDURE proc_example_u(...) ..."
}
```

Generated config maps role `u` to that SQL procedure under
`Roles.u.Issuers.db.Sql`. Login requests are handled by the generated app
against the generated app's runtime database.

For the `u` role above, generated `conf/config.json` also maps:

- `Roles.u.Id_name` to `fields.id`.
- `Roles.u.Issuers.db.Credential` to `fields.login`, `fields.password`,
  `direct`, and the role surface name.
- `Roles.u.Issuers.db.In_pars` to the login and password fields.
- `Roles.u.Issuers.db.Out_pars` to the role id, login, firstname, and lastname
  attributes returned by the login procedure.

The login endpoint shape is:

```text
<script>/<role>/json/login
```

For the template app:

```text
/example/app.php/u/json/login
```

Submit the login and password field names from `fields`, such as `email` and
`passwd`. A successful login sets the generated Genelet role session/cookie.
After that, the same client can call protected actions, for example:

```text
/example/app.php/u/json/item?action=topics
/example/app.php/u/json/item?action=edit&item_id=1
```

The generator does not seed runtime users. Add seed data yourself or make the
login procedure validate against whatever user table you deploy. The template
procedure is intentionally minimal and should be replaced for a real app.

`isAdmin` is optional role metadata. Non-admin roles are supported; component
permissions are controlled by component action groups, not by the admin flag.

## Components And Permissions

Each component needs a backing table:

```json
{
  "name": "item",
  "table": "item",
  "public": ["topics"],
  "roles": {
    "u": ["startnew", "insert", "edit", "update", "topics"]
  }
}
```

`public` lists actions available to `project.publicRole`. `roles` maps each
non-public role name to its allowed actions. Common generated actions are
`topics`, `startnew`, `insert`, `edit`, `update`, and `delete`.

The generator writes those permissions to each component's `component.json`.
The generated endpoint shape is:

```text
<script>/<role>/<tag>/<component>?action=<action>
```

Examples:

```text
/example/app.php/p/json/item?action=topics
/example/app.php/u/json/item?action=edit&item_id=1
```

Each generated archive also includes:

- `api.json`, a machine-readable Tavola API manifest.
- `openapi.json`, an OpenAPI 3.0 document derived from `api.json` for external
  tooling. Tavola-specific action details are kept in `x-tavola-*`
  extensions.
- `docs/api.md`, generated endpoint documentation derived from `api.json`.

These files are emitted for PHP and Perl output and are still generated when
`--no-web-ui` is used.

## Overlays

Use `overlays` when generated defaults are not enough. Component overlays can
replace generated PHP `Filter` or `Model` files, Go `filter.go` or `model.go`
files, and `componentJsonFile` can replace the generated component action
contract. Use `goFilterFile` and `goModelFile` for Go component overlays.
Go overlays are direct JSON generation only; metadata DB import rejects them
instead of silently dropping them.
`componentJson` and
`componentJsonFile` are validated during generation/import and must include the
standard component contract keys: `actions`, `current_table`, `current_key`,
`insert_pars`, `edit_pars`, `update_pars`, and `topics_pars`. See
[Custom Code Overlays](custom-code-overlays.md).

## Introspection Metadata

Specs generated by sqlmeta include:

- `introspection.source`: currently `sqlmeta`.
- `introspection.warnings`: human-readable review items for synthesized DDL,
  missing login procedures, skipped relationships, and other caveats.
- `introspection.warningDetails`: machine-readable diagnostics with
  `code`, `severity`, and `message`. `message` mirrors the warning string so
  existing consumers can keep using `warnings` while tests and automation assert
  stable codes.
