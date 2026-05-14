# No-UI Plan 1: Headless Tabilet Generator

## Goal

Remove the Tabilet web UI/runtime from `main` while keeping the current
database-backed generation path working. This is the short-term no-UI milestone:
JSON specs still import into the Tabilet metadata database, and the existing
export code still produces generated application packages.

The `ui` branch is the archival branch for the current interactive Tabilet UI.
After this milestone, `main` should be safe to treat as a headless generator
tool rather than a hosted web application.

## Keep

- `script/import-project-spec`
- `specs/*.project.json` and related SQL spec files
- `lib/Tabilet/Project/Spec.pm`
- `lib/Tabilet/Generator/PHP.pm`
- `lib/Tabilet/Generator/Perl.pm`
- `lib/Tabilet/Generator/Config.pm`
- `lib/Tabilet/Template/*` used to generate application files
- `conf/init.sql` and schema initialization needed for the metadata database
- metadata database models and helpers required by import/export
- the Jenny regeneration workflow:
  `JSON spec -> Tabilet metadata DB -> export path -> generated app`

Generated application `views/`, Vue files, `www/app.html`, and
`www/index.html` are still part of the generated output. They are not the
Tabilet tool UI and should not be removed in this milestone.

## Extract

Move `Tabilet::Project::Filter::get_tar` out of the web workflow before
removing UI modules. The export logic currently lives in
`lib/Tabilet/Project/Filter.pm`, which is coupled to the old request/action
surface.

Create a non-UI export boundary, for example:

- `lib/Tabilet/Project/Exporter.pm`
- `script/export-project` or a subcommand-style generator CLI

The extracted exporter should accept explicit project identity/options, load the
same metadata records, and produce the same tar/output contents as the current
`get_tar()` flow.

## Remove After Extraction

Remove only after the exporter is covered by smoke checks:

- `script/tabi`
- `cgi-bin/*`
- root Tabilet website pages under `www/`
- Tabilet web UI assets under `www/assets/`, `www/images/`, and related static
  website files
- Tabilet tool views under `views/`
- web-only workflow modules for member/admin/public screens
- payment, subscription, and account-management code that only exists to run
  the hosted Tabilet website

Do not remove generator modules, spec import code, metadata schema, or generated
application templates as part of this first no-UI step.

## Work Items

1. Add a headless exporter module that owns the tar/output generation logic.
2. Add a CLI entrypoint for exporting a metadata DB project without running the
   Tabilet web app.
3. Preserve the current metadata DB import path from JSON specs.
4. Update development checks to compile the importer and exporter CLI instead
   of the removed web entrypoints.
5. Remove the Tabilet web runtime files after the headless exporter matches the
   old export output.
6. Update `README.md` so generation instructions describe the headless flow.

## Verification

1. Run `script/import-project-spec --dry-run --spec specs/jenny.project.json`.
2. Import Jenny into a disposable metadata database with
   `script/import-project-spec --replace`.
3. Export Jenny through the new headless exporter.
4. Compare generated structure against the current `get_tar()` output for the
   same metadata records.
5. Run Composer validation and PHP lint on the generated PHP package.
6. Compile remaining Perl modules and scripts.

## Acceptance Criteria

- Jenny can still regenerate from `specs/jenny.project.json` through the
  Tabilet metadata database and export path.
- No Tabilet web server, CGI entrypoint, or browser UI is required to generate
  an application package.
- The generated Jenny package contains the same required config, SQL, PHP/Perl
  source, component JSON, Vue, Twig/view, and static runtime files.
- The no-UI removal does not delete generated-application template support.
