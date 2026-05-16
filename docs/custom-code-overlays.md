# Custom Code Overlays

Tavola project specs keep generated app structure in JSON and allow explicit
custom-code overlays for files that should not be regenerated from defaults.
Use overlays when a component needs hand-written behavior in its generated
filter or model file.

## Source Of Truth

Keep these concerns separate:

- `specs/*.project.json` is the source of truth for metadata: project settings,
  datasource, schema records, roles, components, action access, and landing
  defaults.
- `specs/*/sql/*.sql` is the source of truth for table and procedure DDL used
  by the generated app.
- Overlay files are the source of truth for custom generated-code files.

Do not edit exported generated files and treat those edits as durable. Put
durable custom code in an overlay file and reference it from the JSON spec.

## Component Overlays

Component overlays replace generated defaults for one component file.

```json
{
  "components": [
    {
      "name": "car",
      "description": "Vehicle recalls",
      "table": "Book3_csv",
      "public": ["startnew", "edit", "topics"],
      "componentJsonFile": "../jenny/src/car/component.json"
    }
  ],
  "overlays": {
    "components": {
      "car": {
        "filterFile": "../jenny/src/car/Filter.php",
        "modelFile": "../jenny/src/car/Model.php",
        "goFilterFile": "overlays/internal/car/filter.go",
        "goModelFile": "overlays/internal/car/model.go"
      }
    }
  }
}
```

For this example:

- `componentJsonFile` provides the component action contract, including custom
  actions like `years`, `makes`, or `history`.
- `filterFile` replaces the generated PHP `src/car/Filter.php`.
- `modelFile` replaces the generated PHP `src/car/Model.php`.
- `goFilterFile` replaces the generated Go `internal/car/filter.go`.
- `goModelFile` replaces the generated Go `internal/car/model.go`.

If an overlay is omitted, Tavola writes its normal generated default for that
file.

Go overlays are supported only by direct JSON generation. The legacy metadata
database import path rejects `goFilter`, `goFilterFile`, `goModel`, and
`goModelFile` because the metadata schema has no columns to preserve them.

`componentJson` and `componentJsonFile` overlays are validated during direct
generation and metadata import. They must be JSON objects with:

- `actions`: an object. Each action entry must be an object; optional `groups`
  and `options` values must be arrays of strings.
- `current_table`: the backing table name.
- `current_key`: the primary key column.
- `insert_pars`, `edit_pars`, `update_pars`, and `topics_pars`: arrays of
  parameter names.

Invalid overlay JSON fails generation/import early with the component name and
the malformed field.

## Project Overlays

The same pattern exists for project-level generated files:

```json
{
  "overlays": {
    "project": {
      "filterFile": "overlays/src/Filter.php",
      "modelFile": "overlays/src/Model.php"
    }
  }
}
```

Use project overlays sparingly. Most custom behavior should live in component
filters and models because it is easier to reason about during regeneration.

## Recommended Layout

For a new project, prefer keeping overlays near the spec:

```text
specs/my.project.json
specs/my/sql/
specs/my/overlays/src/car/Filter.php
specs/my/overlays/src/car/Model.php
specs/my/overlays/internal/car/filter.go
specs/my/overlays/internal/car/model.go
```

Then reference them with paths relative to the spec file:

```json
{
  "overlays": {
    "components": {
      "car": {
        "filterFile": "my/overlays/src/car/Filter.php",
        "modelFile": "my/overlays/src/car/Model.php",
        "goFilterFile": "my/overlays/internal/car/filter.go",
        "goModelFile": "my/overlays/internal/car/model.go"
      }
    }
  }
}
```

Jenny is an example generated app name used in this repository to mark output
created by Tavola; it is not part of Tavola itself. It currently references
files from `../jenny/src/car/` to preserve the existing custom implementation
during migration. For newer projects, keeping overlays inside `specs/` makes
the JSON source-of-truth package more portable.

## Rules For Overlay Code

- Keep generated framework boilerplate compatible with the current generator:
  namespace or package name, parent/embedded type, method signatures, and
  return types should match the generated file shape.
- Add custom logic inside existing lifecycle methods when possible.
- For custom model actions, add the action to `componentJsonFile` or
  `componentJson` so the generated app knows the route exists.
- Do not put secrets, deployment paths, or runtime credentials in overlay code.
  Use generated config and environment variables instead.
- Keep static assets separate from metadata overlays. Jenny's `www/cars/`
  assets are copied during regeneration; they are not stored in the Tavola
  metadata database.

## Regeneration Checklist

1. Update the JSON spec for metadata changes.
2. Update SQL fragments for schema/procedure changes.
3. Update overlay files for custom PHP behavior.
4. Run `script/generate-project --dry-run --lang php --spec specs/my.project.json`.
5. Generate into a disposable output directory with `--replace`.
6. Verify Composer, PHP lint, generated SQL import,
   and any custom routes named in `componentJsonFile`.
