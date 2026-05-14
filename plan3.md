# Plan 3: Regenerate Jenny From JSON

## Goal

Regenerate the Jenny PHP base in `../jenny` from the JSON source-of-truth,
through the Tabilet metadata database export path, while preserving explicit
Jenny overlays.

## Repository

- Worktree: `/home/peter/Workspace/jenny`
- Branch: `main`
- Historical reference branch: `master`
- Framework requirement: `genelet/php ^1.3.2`

## Regeneration Path

Use `specs/jenny.project.json` as the source-of-truth for Tabilet metadata.
The importer loads that JSON into a disposable Tabilet metadata database; the
existing export path generates the PHP package from those records.

1. Start a disposable Docker MySQL database.
2. Load the Tabilet metadata schema with `conf/init.sql`.
3. Import `specs/jenny.project.json` with `script/import-project-spec --replace`.
4. Export and generate the PHP package from Tabilet.
5. Copy Jenny static/runtime overlays that are intentionally outside metadata.

## JSON Source Of Truth

Jenny metadata now lives in:

- `specs/jenny.project.json`: owner, project, datasource, roles, components,
  action access, landing defaults, and custom code overlay references.
- `specs/jenny/sql/*.sql`: generated app table and procedure DDL.
- `docs/custom-code-overlays.md`: rules for custom generated-code overlays.

The importer writes Tabilet metadata records only. The generated Jenny app's
own runtime database is still initialized from the exported app's
`conf/init.sql`.

## Jenny Overlays To Preserve

Preserve Jenny-specific files and assets from the old code:

- `src/car/Filter.php`, referenced by `specs/jenny.project.json`.
- `src/car/Model.php`, referenced by `specs/jenny.project.json`.
- `www/cars/` assets and data, copied outside the metadata importer.
- `README`
- `.gitignore`
- `conf/sample_config.json`

## Generated App Requirements

- Depend on `genelet/php ^1.3.2`.
- Include modern `Application.php`, Beacon classes, and bootstrap files.
- Use env-backed sample config.
- Keep deployment secrets out of Git.
- Leave `master` as the old-code reference until explicitly removed.

## Verification

1. Run `script/import-project-spec --dry-run --spec specs/jenny.project.json`.
2. Import the spec into a disposable Tabilet metadata database.
3. Assert expected rows in `member`, `user_project`, `user_ds`, `user_table`,
   `user_procedure`, `user_role`, `user_component`, and `user_action_public`.
4. Run the existing `get_tar()` export path against the imported Jenny project.
5. Run `composer validate` on the exported package.
6. Run PHP lint on the exported package.
7. Import exported `conf/init.sql` into Docker MySQL.
8. Run a generated app bootstrap smoke test.
9. Verify key Jenny JSON routes:
   - `question?action=topics`
   - `car?action=years`
   - `car?action=makes`
   - `car?action=history`

## Acceptance Criteria

- Jenny is regenerated from Tabilet's database export flow.
- Jenny project metadata is regenerated from `specs/jenny.project.json`.
- Jenny-specific code overlays and static assets are preserved.
- Generated code targets `genelet/php ^1.3.2`.
- Sample config is env-backed and contains no deployment secrets.
- Composer, lint, SQL import, bootstrap, and key JSON route checks pass.
