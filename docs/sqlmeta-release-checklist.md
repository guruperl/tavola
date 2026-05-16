# Sqlmeta Workflow Release Checklist

This workflow is local-only during development. Run it from the Tavola repo
with sibling checkouts at `../sqlmeta`, `../molecule`, and `../golet`.
GitHub CI for these repos is manual-dispatch only; the local workflow below is
the required release gate before pushing sqlmeta contract bumps.

## Fast Gate

Use this while iterating on sqlmeta contracts or Tavola direct generation:

```bash
script/verify-sqlmeta-workflow --fast
```

It refreshes generated contract fixtures, checks drift, runs `sqlmeta` Go tests,
runs Tavola Go tests for direct sqlmeta and compatibility generation, and
verifies the reviewed SupportDesk compatibility fixture.

## Integration Gate

Use this before bumping downstream modules or publishing commits:

```bash
script/verify-sqlmeta-workflow --integration
```

It runs the Docker-backed molecule and golet database harnesses and `golet` vet.

## Bump Order

1. Commit and push `sqlmeta`.
2. In `molecule`, bump `github.com/genelet/sqlmeta` to the new commit, run the
   molecule harness, then commit and push.
3. In `golet`, bump `github.com/genelet/sqlmeta` and
   `github.com/genelet/molecule`, run the golet harness and vet, then commit and
   push.
4. In `tavola`, bump `github.com/genelet/sqlmeta`, commit direct-generation
   tests/docs plus any compatibility fixture updates that consume the new
   contract, then run `script/verify-sqlmeta-workflow --all` and push only if it
   passes.

If the drift check fails, run:

```bash
cd ../sqlmeta
./script/refresh-contract-fixtures
cd ../tavola
./script/refresh-contract-fixtures
```

Then review and commit the generated sqlmeta neutral fixtures plus Tavola's
`testdata/sqlmeta/contracts` snapshots and `specs/sqlmeta.project.json` change.
