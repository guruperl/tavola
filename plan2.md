# Plan 2 - Refactor golet Genesis to Use sqlmeta

## Goal

Move golet's user-team CRUD discovery from local molecule FK traversal to the
shared sqlmeta app-spec expansion path.

This plan is tracked in `../golet/memory-bank/status.md` under:

- `Sqlmeta dependency promoted`
- `Genesis role expansion refactored`
- `Manual PK/FK role scope covered`
- `Golet regression suite verified`

## Tasks

1. Promote sqlmeta in golet.
   - Add a direct import of `github.com/genelet/sqlmeta/xmeta` where genesis
     constructs app specs or schema overrides.
   - Ensure `go.mod` records sqlmeta as a direct dependency if code imports it.
   - Keep `molecule` as the query/atom generation dependency.

2. Add an option carrier for genesis.
   - Preserve existing APIs such as `AutoRefresh`, `AutoTeams`, and
     `NewFullRDSConfig`.
   - Add option-bearing variants only where needed, for example
     `AutoRefreshWithOptions`, `AutoTeamsWithOptions`, or a compact
     `genesis.AutoOptions`.
   - Include optional fields for `Schemas`, `SchemaOverrides`, `RoleScope`, and
     `FallbackAllTables`.

3. Map golet auth to sqlmeta auth binding.
   - Convert `authenticator.Auth.UserTableName` to `xmeta.AuthBinding.UserTable`.
   - Convert `authenticator.Auth.UserIDName` to `UserIDColumn`.
   - Derive login/password columns from existing issuer input parameters when
     available; otherwise leave them empty and preserve existing runtime auth.
   - Use the golet team name as `AppRole.Name`.

4. Replace local traversal in `genesis/usertable.go`.
   - Build an app spec with `xmeta.BuildDefaultAppSpec`.
   - Expand it with `xmeta.ExpandRoleScopes`.
   - Stop using local `forwardReference`, `resolveTableName`, `userTableProps`,
     and recursive assignment as the source of truth for table discovery.
   - Keep any small helper only if it maps expanded grants to golet colors.

5. Map `ExpandedTableGrant` to `squad.Colorful`.
   - Auth table grant becomes `squad.NewColor(true, false, userIDColumn)`.
   - Direct child grant becomes `squad.NewColor(false, true, childColumn)`.
   - Descendant grant becomes `squad.NewColor(false, false, childColumn)`.
   - Use `TraversalJoins` to pick the scoped column; the last join child column
     is the protected column for descendant tables.
   - Exclude tables not granted by `ExpandedAppSpec` from non-admin teams.

6. Preserve team behavior.
   - Admin teams still receive all molecule atoms.
   - Public teams still receive admin atoms minus protected user-role atoms.
   - Existing errors remain meaningful, including missing teams and missing auth.
   - Replace the strict PK/user-id mismatch check with sqlmeta's auth table
     validation so manual PK can intentionally choose the app user id.

7. Cover manual PK/FK.
   - Add tests where the physical user PK is `id`, the app user id is
     `public_id`, and a child table references `public_id` only through
     `SchemaRelationshipOverrides`.
   - Assert the child table appears in the user team and the unrelated table
     does not.
   - Assert protected colors use the manual FK child column.

## Verification

Run in `../golet`:

```bash
go test -p 1 ./genesis/... ./squad/... ./serve/... ./openapi/...
go test -p 1 ./...
```

If a database-backed test needs external configuration, document the exact
missing variable, for example `POSTGRES_DSN`.
