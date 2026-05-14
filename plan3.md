# Plan 3: Regenerate Jenny Base

## Goal

Regenerate the Jenny PHP base in `../jenny` through the Tabilet database export path, then preserve Jenny-specific overlays from the old codebase.

## Repository

- Worktree: `/home/peter/Workspace/jenny`
- Branch: `main`
- Historical reference branch: `master`
- Framework requirement: `genelet/php ^1.3.2`

## Regeneration Path

Use the Tabilet database export path rather than file-only regeneration.

1. Start a disposable Docker MySQL database.
2. Load the Tabilet schema.
3. Seed or reconstruct the Jenny project records.
4. Export and generate the PHP package from Tabilet.

## Jenny State To Reconstruct

Reconstruct Jenny database state from the old Jenny app where needed:

- Project config.
- Admin role.
- Data source.
- Table SQL and procedure SQL.
- Component definitions.
- Component actions.
- Landing pages.
- Generated view expectations.

## Jenny Overlay To Preserve

Preserve Jenny-specific files and assets from the old code:

- `src/car/Filter.php`
- `src/car/Model.php`
- `www/cars/` assets and data
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

1. Run `composer validate`.
2. Run PHP lint.
3. Import SQL into Docker MySQL.
4. Run a generated app bootstrap smoke test.
5. Verify key Jenny JSON routes:
   - `question?action=topics`
   - `car?action=years`
   - `car?action=makes`
   - `car?action=history`

## Acceptance Criteria

- Jenny is regenerated from Tabilet's database export flow.
- Jenny-specific overlays are preserved.
- Generated code targets `genelet/php ^1.3.2`.
- Sample config is env-backed and contains no deployment secrets.
- Composer, lint, SQL import, bootstrap, and key JSON route checks pass.

