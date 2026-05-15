# Plan 3 - Make Tavola Consume sqlmeta Output

## Goal

Keep Tavola as an output target for sqlmeta app specs. Tavola should consume
expanded metadata and generated project JSON rather than owning generic
database role traversal.

## Tasks

1. Treat `tavola-introspect` as the bridge.
   - Use `../sqlmeta/cmd/tavola-introspect` to introspect a live database and
     emit Tavola project JSON.
   - Ensure Tavola-side docs and examples point users to that CLI for database
     to project-spec bootstrapping.

2. Verify generated Tavola JSON shape.
   - Confirm project, datasource, schema tables, procedures, roles, components,
     action access, and introspection warnings are present where expected.
   - Confirm protected roles use sqlmeta-expanded CRUD grants.
   - Confirm the public role remains Tavola's unauthenticated role, usually `p`.

3. Verify auth role mapping.
   - Auth role fields come from `AuthBinding`: user table, id, login,
     password, first name, and last name.
   - Auth table existence is mandatory before role expansion.
   - Missing login procedure or synthesized DDL appears as a warning rather than
     hidden behavior.

4. Verify manual PK/FK effects.
   - A manual PK changes the app-level role id field in generated role config.
   - A manual FK changes which child tables are granted to the auth role.
   - Unrelated tables are excluded from protected role CRUD unless explicit
     all-table fallback is requested.

5. Update fixtures only when behavior changed intentionally.
   - Add or adjust `specs/*.project.json` examples if they need manual
     `SchemaRelationshipOverrides` coverage.
   - Keep Tavola tests focused on the JSON contract, not sqlmeta internals.

## Verification

Run in `../tavola`:

```bash
prove -Ilib -I../perl t/*.t
```

For sqlmeta CLI verification, run the relevant `go run
../sqlmeta/cmd/tavola-introspect` command against a local database fixture and
compare the generated JSON to the expected Tavola project contract.
