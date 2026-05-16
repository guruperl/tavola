# Sqlmeta Introspection

Tavola's Go generator consumes `sqlmeta` metadata directly. Generic database
traversal, auth role scope, and manual PK/FK interpretation belong to sqlmeta;
Tavola owns the generated archive, runtime config, component JSON, API docs, and
language emitters. Tavola JSON remains a compatibility input and fixture/export
format, not the required bridge for Go generation.

## Workflow

1. Run `cmd/tavola-generate` with either live database flags or a saved
   `MetaDatabase` file.
2. Pass project metadata, datasource values, and optional auth binding fields.
3. Pass `--relationship-overrides` when the app needs virtual PK/FK relationships that
   differ from the physical database.
4. Review generated `api.json` or `docs/api.md` introspection warnings before
   publishing the generated app. Use `api.json.introspection.warning_details`
   when automation needs stable diagnostic codes.

Example:

```bash
GOWORK=off go run ./cmd/tavola-generate \
  --driver sqlite3 \
  --dsn /path/to/app.sqlite \
  --database app.sqlite \
  --project SqlmetaApp \
  --script /sqlmeta/app.php \
  --ds-nickname sqlmeta \
  --ds-path data/sqlmeta.sqlite \
  --auth-role u \
  --auth-table users \
  --auth-id public_id \
  --auth-login email \
  --auth-password passwd \
  --auth-firstname firstname \
  --auth-lastname lastname \
  --relationship-overrides overrides.textpb \
  --lang go \
  --out build/sqlmeta-app \
  --replace
```

Library callers should use `GenerateFromSQLMeta` for default app expansion,
`GenerateFromExpandedApp` when they already have an expanded app, and
`GenerateFromExpandedAppWithDiagnostics` when they need stable expansion
diagnostic codes preserved in generated API metadata.

## Contract

- `project.publicRole` remains Tavola's unauthenticated role, conventionally
  `p`.
- `roles[]` entries come from sqlmeta auth bindings. The role table is mandatory
  for protected role expansion.
- `components[].roles` contains the CRUD grants from sqlmeta's
  `ExpandedAppSpec`; Tavola does not recompute FK traversal.
- Manual PK overrides appear as Tavola table `primaryKey` and role field `id`.
- Manual FK overrides affect which components receive protected role CRUD.
- Tables outside the expanded role scope stay public-only unless sqlmeta was run
  with explicit all-table fallback.
- `introspection.warnings` is the review surface for synthesized DDL, manual
  override decisions, missing login procedures, skipped relationships, and other
  introspection caveats.
- `introspection.warningDetails` mirrors `introspection.warnings` with
  `{code,severity,message}` objects so package tests and workflow automation can
  assert warning semantics without parsing prose.
- Auth login procedure metadata can be supplied by an expanded sqlmeta app spec.
  Otherwise Tavola keeps the role for review and surfaces the missing-procedure
  warning in generated API metadata.

## Reviewed Source-Of-Truth

`specs/supportdesk.project.json` is the current reviewed compatibility fixture.
It was generated from `specs/supportdesk/schema.sql`, then edited as an
application contract: the landing route, role restriction, login SQL,
descriptions, and public/protected component actions are deliberate JSON
decisions. Do not regenerate over that file without reviewing the
application-level changes again.

The package boundary is:

- `sqlmeta` owns database introspection, neutral `ExpandedAppSpec` contract
  fixtures, FK role expansion, relationship overrides, and diagnostics.
- `tavola` owns direct generation from sqlmeta inputs, compatibility Tavola JSON
  specs, generated archives, runtime config, component JSON, API docs, and
  language emitters.
- `molecule` and `golet` continue to consume `sqlmeta` at the metadata/loader
  level. They should not consume `ExpandedAppSpec` directly until they need app
  intent semantics such as Tavola-style role grants or component CRUD policy.

The reviewed fixture also has generated-app smoke coverage:

```bash
script/smoke-generated-project --spec specs/supportdesk.project.json --lang all
script/smoke-sqlite-init
```

`smoke-generated-project` validates the exported PHP, Perl, and Go project
packages.
`smoke-sqlite-init` regenerates a PHP package, executes the full generated
`conf/init.sql` in an in-memory SQLite database, compares that schema against
`specs/supportdesk/schema.sql`, and inserts linked rows through the generated
foreign keys. SQLite does not support stored procedure DDL, so the generator
emits comments for those procedures in SQLite init SQL while preserving the
login procedure binding in generated config and API metadata.

## Local Verification

Run the local cross-repo workflow from this repo:

```bash
script/verify-sqlmeta-workflow --fast
script/verify-sqlmeta-workflow --integration
script/verify-sqlmeta-workflow --all
```

The GitHub workflows are intentionally manual-dispatch. Treat `--all` as the
mandatory local release gate before pushing a sqlmeta dependency ladder.

The script first runs `../sqlmeta/script/refresh-contract-fixtures` for neutral
`ExpandedAppSpec` fixtures, then `script/refresh-contract-fixtures` for
Tavola-owned project JSON, warning snapshots, and
`specs/sqlmeta.project.json`.

`--fast` checks fixture drift, canonical `sqlmeta` tests, Tavola Go tests for
direct `GenerateFromSQLMeta` and `cmd/tavola-generate` modes, compatibility Perl
consumer tests, and the generated-app and SQLite init smoke checks above.

`--integration` runs the Docker-backed `molecule/rdb` and `golet/genesis`
harnesses plus `golet` vet. `--all` runs both paths and remains the default
when no mode is provided.
