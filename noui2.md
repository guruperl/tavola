# No-UI Plan 2: Direct JSON Generator

## Goal

Make JSON specs the primary generator input and bypass the Tabilet metadata
database for normal generation.

Add a direct CLI such as:

```bash
script/generate-project --lang php --spec specs/jenny.project.json --out ../jenny
script/generate-project --lang perl --spec specs/example.project.json --out ./build/example
```

The metadata database importer remains available as a compatibility and
migration path, but day-to-day generation should not require creating or
populating Tabilet metadata tables.

## Target Flow

```text
JSON project spec
  -> validated in-memory project model
  -> PHP or Perl generator
  -> output directory or tar archive
```

The in-memory model should represent the same project concepts currently stored
in the metadata DB: owner, project, datasource, tables, procedures, roles,
components, action access, landing defaults, and custom generated-code overlay
references.

## CLI Contract

`script/generate-project` should support at least:

- `--lang php|perl`
- `--spec PATH`
- `--out PATH`
- `--tar PATH` or an equivalent archive option
- `--replace` or a clearly named overwrite mode for output directories
- `--dry-run` to validate and summarize planned generation without writing

Generation defaults should match the current PHP/Perl generators unless the JSON
spec explicitly overrides them.

## Implementation Notes

- Reuse the JSON parsing and validation already present in
  `lib/Tabilet/Project/Spec.pm` where practical.
- Introduce a project model boundary before generator-specific code. Avoid
  having PHP and Perl generators read raw JSON shape directly.
- Keep custom overlay handling explicit and deterministic.
- Preserve generated app support for `views/`, Vue files, `www/app.html`, and
  `www/index.html`.
- Keep metadata DB import/export tests as compatibility coverage, not the
  primary path.

## Compatibility Path

The DB-backed flow should remain available while consumers migrate:

```text
JSON project spec
  -> script/import-project-spec
  -> Tabilet metadata DB
  -> headless exporter
```

This path is useful for validating parity with legacy Tabilet metadata and for
debugging migrations, but it should no longer be required to regenerate Jenny.

## Work Items

1. Define an in-memory project model shared by direct generation and DB import.
2. Teach the JSON spec loader to build that model without writing metadata DB
   records.
3. Add `script/generate-project`.
4. Connect PHP and Perl generation to the model.
5. Add fixtures for PHP and Perl smoke generation.
6. Keep DB importer compatibility checks so regressions are visible.
7. Update docs to make the direct JSON command the default regeneration path.

## Verification

1. Run direct PHP generation from `specs/jenny.project.json`.
2. Run direct Perl generation from a representative fixture spec.
3. Assert generated directory structure for config, SQL, source, component JSON,
   views, Vue, and static runtime files.
4. Run Composer validation and PHP lint on the PHP fixture.
5. Compile generated Perl modules for the Perl fixture.
6. Run DB-backed importer/exporter parity checks against at least one fixture.

## Acceptance Criteria

- Jenny regenerates from JSON directly without creating a Tabilet metadata
  database.
- `script/generate-project --lang php --spec specs/jenny.project.json --out ...`
  produces the expected generated app structure.
- PHP and Perl smoke fixtures verify the generator output shape.
- The DB importer remains documented and functional as a compatibility path.
