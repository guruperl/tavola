# Plan 4 - Cross-Repo Verification and Release Order

## Goal

Verify the full `sqlmeta -> molecule/golet/tavola` workflow and commit changes
in dependency order so each repo can be consumed independently.

## Tasks

1. Verify dependency direction.
   - `sqlmeta` has no dependency on `molecule`, `golet`, or Tavola.
   - `molecule/rdb` imports `github.com/genelet/sqlmeta/xmeta`.
   - `golet` imports `github.com/genelet/sqlmeta/xmeta` only for app-spec and
     role expansion, while still using molecule for atoms and execution.
   - Tavola consumes sqlmeta output through project JSON or CLI output.

2. Verify import paths and replaces.
   - Confirm no repo uses `github.com/tabilet/sqlmeta`.
   - Confirm local development uses `github.com/genelet/sqlmeta`.
   - Use `GOWORK=off` in repos where local `replace` directives must win over
     the parent workspace.

3. Run verification in dependency order.
   - `sqlmeta` first, including proto generation check.
   - `molecule` second, including Docker-backed database harness.
   - `golet` third, including genesis and full regression tests.
   - Tavola last, including Perl project-spec and generated-project tests.

4. Commit in dependency order.
   - Commit `sqlmeta` first.
   - Commit `molecule` after it passes against the committed sqlmeta shape.
   - Commit `golet` after it passes against sqlmeta and molecule.
   - Commit `tavola` last, including only plan/docs/fixture changes intended
     for Tavola.

5. Record blockers precisely.
   - For skipped database tests, name the missing env var or external service.
   - For generated-code drift, name the command that must be run.
   - For workspace mismatch, record whether `GOWORK=off` was required.

## Verification Commands

```bash
cd ../sqlmeta
cd proto && protoc -I=. --go_out=../xmeta --go_opt=paths=source_relative *.proto
cd ..
GOWORK=off go test ./...

cd ../molecule
GOWORK=off MOLECULE_MYSQL_PORT=3317 MOLECULE_POSTGRES_PORT=5443 ./scripts/harness-test.sh ./...

cd ../golet
go test -p 1 ./...

cd ../tavola
prove -Ilib -I../perl t/*.t
```

Acceptance is a clean status in each repo except for explicitly unrelated user
changes, passing verification, and separate commits in dependency order.
