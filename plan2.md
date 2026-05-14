# Plan 2: Finalize Tabilet PHP Generator

## Goal

Finalize the Tabilet PHP generator in `/home/peter/Workspace/tabilet` so generated PHP applications target the modern Genelet PHP framework and remain compatible with the updated `../php/samples/project-php` shape.

## Repository

- Worktree: `/home/peter/Workspace/tabilet`
- Branch: `main`
- Default framework requirement: `genelet/php ^1.3.2`
- Local development framework requirement: path repository to `../php` with `dev-main || dev-master`

## Constraints

- Preserve the current uncommitted PHP generator work unless verification exposes a defect.
- Do not change generated app semantics beyond modernization and framework compatibility.

## Work Items

1. Update Composer generation defaults.
   - Set the public default requirement to `genelet/php ^1.3.2`.
   - Keep local development mode using `../php`.
   - Allow local path repository versions `dev-main || dev-master`.

2. Keep generated app output aligned with `../php/samples/project-php`.
   - Generate `src/Application.php`.
   - Keep `www/app.php` thin.
   - Generate project and component Beacon classes.
   - Support generic environment expansion.
   - Support database environment overrides.
   - Keep the corrected `get_lb_ip()` behavior.

3. Keep export and tar packaging complete.
   - Include generated Composer files.
   - Include config.
   - Include SQL.
   - Include base classes.
   - Include component JSON.
   - Include filters and models.
   - Include Beacon classes.
   - Include Vue files.
   - Include Twig views.
   - Include static `genelet.js`.

4. Verify generator health.
   - Run a full Perl module compile sweep.
   - Verify `script/tabi`.
   - Verify `cgi-bin/xtabi`.
   - Lint generated PHP through Docker.
   - Validate public Composer output.
   - Validate local Composer output.
   - Dry-run local `../php` path repository install.
   - Run existing Genelet Perl tests.

## Acceptance Criteria

- Generated public Composer files depend on `genelet/php ^1.3.2`.
- Generated local Composer files can resolve `../php` from `main` or `master`.
- Generated PHP layout matches the modern framework sample app.
- Tar/export output includes all runtime, source, view, SQL, and static assets needed by the generated app.
- Existing semantics are preserved except for modernization required by the new framework target.

