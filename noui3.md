# No-UI Plan 3: Template Boundary and Residual Issues

## Goal

Document the boundary left after the Tabilet tool UI is removed and identify the
remaining generator cleanup work. The important distinction is:

- remove the Tabilet website and web workflow UI from `main`
- keep generated application UI output supported by the generator

The generated application UI is still part of the product. The Tabilet tool UI
is the piece being retired from `main`.

## Template Boundary

Keep `lib/Tabilet/Template/*` for now. These modules generate application files,
including:

- generated app `views/`
- Vue files
- `www/app.html`
- `www/index.html`
- role/component landing pages and related generated UI glue

Those files belong to generated applications. They are not the Tabilet web UI
that lives in `script/tabi`, `cgi-bin/*`, root `views/`, and root `www/`
website assets.

The template modules should only be removed or rewritten after direct JSON
generation has replacement coverage for all generated app output.

## Desired Boundary

After UI removal, the repo should read as a generator:

- specs describe generated applications
- importer and compatibility tools translate specs into metadata when needed
- generator modules produce PHP/Perl application code
- template modules produce generated application UI/runtime files
- no hosted Tabilet account/project editing UI remains on `main`

This boundary allows Jenny and other generated apps to keep their browser-facing
application pages while removing the Tabilet builder website itself.

## Residual Issues

### PHP and Perl parity

Direct generation must keep PHP and Perl output intentionally aligned. Where the
languages cannot share exact structure, the difference should be documented and
covered by smoke fixtures.

### Generated formatting

Generated PHP, Perl, JSON, Twig/view, and Vue output should be deterministic and
stable. Formatting-only diffs should not appear during repeated regeneration
from the same spec.

### Component JSON normalization

Component JSON should have a single normalized shape. The generator should avoid
mixing metadata DB quirks, hand-written spec quirks, and language-specific
serialization differences.

### Static asset overlays

Generated app static assets and project-specific overlays need explicit rules:

- which assets come from generator defaults
- which assets come from the JSON spec
- which assets are copied as project overlays
- which files are intentionally never overwritten

Jenny assets such as `www/cars/` should stay outside metadata unless they are
made explicit overlays in the spec.

### Composer version mismatch

Generated PHP Composer output should continue to target the intended public
framework version while local development can use a sibling path repository.
Keep the public requirement and local path repository behavior documented
together so generated apps do not drift.

### Metadata schema leftovers

Once direct JSON generation is the primary path, audit remaining metadata schema
usage. Keep tables and models only where they support compatibility, migration,
or tests. Remove schema dependencies from the primary generation path.

## Work Items

1. Label generator templates as generated-app templates in docs and module
   comments where helpful.
2. Add fixture coverage that proves generated app UI output survives Tabilet UI
   removal.
3. Normalize component JSON generation.
4. Define overlay copy/overwrite behavior.
5. Document PHP/Perl parity expectations and known differences.
6. Audit metadata DB dependencies after direct generation is stable.

## Verification

1. Generate Jenny through the current supported path.
2. Verify generated app `views/`, Vue files, `www/app.html`, and
   `www/index.html` are still present.
3. Regenerate the same fixture twice and confirm deterministic output.
4. Run PHP and Perl smoke fixtures.
5. Confirm no root Tabilet tool UI files are required by the generator.

## Acceptance Criteria

- The repo has a clear documented distinction between removed Tabilet UI and
  supported generated-app UI.
- `lib/Tabilet/Template/*` remains until replacement generator coverage exists.
- Residual cleanup issues are tracked with concrete verification points.
- Jenny regeneration keeps generated app UI support after the Tabilet tool UI is
  gone.
