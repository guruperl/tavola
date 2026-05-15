# Project Spec Reference

Tabilet project specs describe the generated application. The JSON spec is the
source of truth for runtime config, database metadata, roles, components,
allowed actions, and optional generated-code overlays.

Start from `specs/project.template.json`. It contains a small app with a public
role `p`, a non-public login role `u`, a login table, one login procedure, and
one protected component.

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

## Owner And Project

`owner.login` is used by the metadata compatibility path and by default path
generation. `project.name` becomes the generated PHP namespace or Perl module
prefix. `project.script` is the public URL prefix handled by the generated app,
for example `/example/app.php`.

`project.publicRole` names the unauthenticated role. The conventional value is
`p`. `project.default` selects the component and action shown when the generated
browser UI starts.

## Datasource

`datasource` configures the generated app's runtime database, not the Tabilet
metadata database. Values can use required environment placeholders:

```json
{
  "user": "${APP_DB_USER}",
  "password": "${APP_DB_PASSWORD}"
}
```

The generated app expands those placeholders at runtime.

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

## Overlays

Use `overlays` when generated defaults are not enough. Component overlays can
replace generated `Filter` or `Model` files, and `componentJsonFile` can replace
the generated component action contract. See
[Custom Code Overlays](custom-code-overlays.md).
