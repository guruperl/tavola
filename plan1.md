# Plan 1 - Stabilize sqlmeta as the Shared Contract

## Goal

Make `github.com/genelet/sqlmeta/xmeta` the stable contract for database
metadata, app intent, auth role scope, and virtual PK/FK relationships before
the downstream repos depend on it more directly.

## Tasks

1. Confirm the public import path.
   - Verify `../sqlmeta/go.mod` declares `module github.com/genelet/sqlmeta`.
   - Verify generated protobuf files use `github.com/genelet/sqlmeta/xmeta`.
   - Verify downstream repos do not still point at `github.com/tabilet/sqlmeta`.

2. Re-check protobuf definitions.
   - Review `proto/app_spec.proto` for `AppSpec`, `AppComponent`, `AppRole`,
     `AuthBinding`, `RoleScope`, `SchemaRelationshipOverrides`,
     `ExpandedAppSpec`, `ExpandedTableGrant`, and traversal joins.
   - Keep AppSpec generic and database/app oriented, not Tavola-specific.
   - Treat README content as semantics documentation only; protobuf remains the
     canonical wire contract.

3. Re-check generated Go helpers.
   - Verify `BuildDefaultAppSpec` builds components from table metadata and
     requires an auth user table when auth scope is requested.
   - Verify `ExpandRoleScopes` follows the virtual schema, not only physical DB
     relationships.
   - Verify warnings are emitted for invalid manual overrides, missing FK
     targets, composite FK traversal skips, cycles, and ambiguous names.

4. Validate virtual schema semantics.
   - Manual PK replaces the physical PK for app-level traversal.
   - Physical PK is still table metadata, but does not win over manual PK for
     role traversal.
   - Manual FK is merged with physical FKs and overrides any physical FK with
     the same child table and child columns.
   - Parent columns omitted from a manual FK default to the effective parent PK.

5. Verify Tavola mapping remains a downstream target.
   - Keep the flow:
     `MetaDatabase -> AppSpec -> ExpandedAppSpec -> TavolaSpec`.
   - Confirm `BuildTavolaSpec` consumes `ExpandedAppSpec` and does not perform
     its own role traversal.

## Verification

Run in `../sqlmeta`:

```bash
cd proto
protoc -I=. --go_out=../xmeta --go_opt=paths=source_relative *.proto
cd ..
GOWORK=off go test ./...
```

Acceptance is no generated-code drift, passing tests, and no downstream import
path mismatch.
