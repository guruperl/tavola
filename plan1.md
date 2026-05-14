# Plan 1: Modernize `../php`

## Goal

Modernize the Genelet PHP framework repository in `../php` while keeping public framework APIs stable. Treat the work as a patch release unless test results prove that a breaking change is unavoidable.

## Repository

- Worktree: `/home/peter/Workspace/php`
- Branch: `main`
- Release target: `1.3.2`
- Compatibility stance: patch release, stable public APIs

## Work Items

1. Clean public packaging.
   - Ensure ignored artifacts remain untracked.
   - Keep `vendor/`, `composer.lock`, logs, and sample runtime state out of Git.
   - Publish `main` instead of relying on `master`.

2. Remove real-looking secrets from samples and code.
   - Replace hard-coded secrets with placeholders or env-backed sample config.
   - Add generic environment expansion to the sample `Application`.
   - Keep Docker test credentials isolated to test harnesses.

3. Update `samples/project-php` to match the modern generated app shape.
   - Include `Application.php`.
   - Include Beacon helpers.
   - Normalize paths consistently.
   - Support environment DB overrides.
   - Configure the Composer path repository to accept `dev-main || dev-master`.

4. Verify the framework and sample app with Docker.
   - Run `composer validate`.
   - Run PHP lint for `src`, `tests`, and the sample app.
   - Run `./scripts/test-docker.sh`.
   - Run `./scripts/test-sample-project-php.sh`.

5. Tag the verified framework release.
   - Tag `1.3.2` only after verification passes.
   - Use `1.3.2` as the default target for generated apps.

## Acceptance Criteria

- `../php` is publishable from `main`.
- Sample config and code contain no hard-coded real-looking secrets.
- `samples/project-php` matches the modern app layout expected by Tabilet.
- Docker verification passes.
- Release tag `1.3.2` exists only after the verified state is ready.

