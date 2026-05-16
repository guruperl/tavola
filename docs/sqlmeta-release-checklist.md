# Sqlmeta Workflow Release Checklist

This workflow is local-only during development. Run it from the Tavola repo
with sibling checkouts at `../sqlmeta`, `../molecule`, and `../golet`.
GitHub CI for these repos is manual-dispatch only; the local workflow below is
the required release gate before pushing sqlmeta contract bumps.

## Fast Gate

Use this while iterating on sqlmeta contracts or Tavola JSON generation:

```bash
script/verify-sqlmeta-workflow --fast
```

It refreshes generated contract fixtures, checks drift, runs `sqlmeta` Go tests,
and verifies Tavola consumption of both generated sqlmeta fixtures and the
reviewed SupportDesk JSON source-of-truth fixture.

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
4. In `tavola`, commit generated specs/docs/tests that consume the new contract,
   then run `script/verify-sqlmeta-workflow --all` and push only if it passes.

If the drift check fails, run:

```bash
cd ../sqlmeta
./script/refresh-contract-fixtures
```

Then review and commit the generated sqlmeta fixture changes and the synced
Tavola `specs/sqlmeta.project.json` change.
