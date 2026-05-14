# Tabilet

Tabilet is a Perl application for generating database-backed web projects and
API services. It builds on the Genelet framework and models an application as
projects, roles, database tables, components, actions, and templates.

Generated projects can expose REST-style endpoints and browser views from the
same component definitions. The repository also contains the public website,
admin/member workflows, schema inspection helpers, code generators, templates,
and integration modules used by the Tabilet service.

## Repository Layout

- `script/` and `cgi-bin/` contain CGI/FastCGI entrypoints.
- `conf/` contains application configuration and database seed SQL.
- `lib/Tabilet/` contains the Tabilet application modules.
- `lib/Extra/` contains local support modules used by the app.
- `views/` contains server-rendered templates.
- `www/` contains static site assets and documentation pages.

## Requirements

- Perl 5
- Genelet framework modules available on `@INC`
- DBI and the database driver for the configured database
- JSON, Template Toolkit, LWP, XML::LibXML, and related modules used by the
  entrypoints
- A MySQL or PostgreSQL database for the full application

For local framework tests, the sibling Genelet repository can run its default
SQLite-backed test suite without a service database.

## Configuration

Runtime secrets and credentials are read from environment variables referenced
as `${NAME}` in `conf/config.json` and `conf/test.json`. The loader in
`Tabilet::Config` expands those values when the application starts and fails
fast if a required environment variable is missing.

Required environment variables:

```text
TABILET_APP_SECRET
TABILET_DB_USER
TABILET_DB_PASS
TABILET_GITHUB_TOKEN
TABILET_GITHUB_CLIENT_ID
TABILET_GITHUB_CLIENT_SECRET
TABILET_MYSQL_ADMIN_USER
TABILET_MYSQL_ADMIN_PASS
TABILET_POSTGRES_ADMIN_USER
TABILET_POSTGRES_ADMIN_PASS
TABILET_PAYPAL_CLIENT_ID
TABILET_PAYPAL_CLIENT_SECRET
TABILET_PAYPAL_WEBHOOK_ID
TABILET_PAYPAL_PRODUCT_ID_1
TABILET_PAYPAL_PRODUCT_ID_2
TABILET_PAYPAL_PRODUCT_ID_3
TABILET_SMTP_AUTH
TABILET_GMAIL_AUTH
TABILET_MEMBER_ROLE_SECRET
TABILET_MEMBER_ROLE_CODING
TABILET_ADMIN_ROLE_SECRET
TABILET_ADMIN_ROLE_CODING
```

The `TABILET_SMTP_AUTH` and `TABILET_GMAIL_AUTH` values use the existing
`user,password` format expected by the mail adapters.

## JSON Project Specs

Tabilet can also load a generated-project definition from JSON into the
Tabilet metadata database. The JSON file becomes the source of truth for the
records that the old UI collected: owner, project, datasource, tables,
procedures, roles, components, action access, landing defaults, and optional
custom generated-code overlays.

Start from the template, then edit the copied spec:

```bash
cp specs/project.template.json specs/my.project.json
```

Initialize the Tabilet metadata database:

```bash
mysql -u root tabilet < conf/init.sql
```

Validate a spec without writing to the database:

```bash
script/import-project-spec --dry-run --spec specs/project.template.json
```

Import or replace a project in the metadata database:

```bash
TABILET_DB_USER=... TABILET_DB_PASS=... \
script/import-project-spec \
  --config conf/config.json \
  --spec specs/jenny.project.json \
  --replace
```

The importer writes Tabilet metadata records only. The generated app still has
its own runtime database, initialized from the exported app's `conf/init.sql`.
After import, export the generated PHP app from the populated Tabilet records:

```bash
TABILET_DB_USER=... TABILET_DB_PASS=... \
script/export-project \
  --config conf/config.json \
  --owner jenny \
  --out ../jenny \
  --replace
```

Use `--tar PATH` instead of `--out PATH` to write an archive without extracting
it. The exporter is headless and does not require the Tabilet web UI, CGI
entrypoints, or browser workflow.

Custom generated-code files should be kept as explicit overlays referenced by
the JSON spec. See [Custom Code Overlays](docs/custom-code-overlays.md).

## Development Checks

Compile the application modules and entrypoints:

```bash
find lib -name '*.pm' | sort | while read -r f; do
  perl -Ilib -I../perl -c "$f" >/dev/null || exit 1
done

perl -Ilib -I../perl -c script/tabi
perl -Ilib -I../perl -c script/import-project-spec
perl -Ilib -I../perl -c script/export-project
perl -Ilib -I../perl -c cgi-bin/tabi
perl -Ilib -I../perl -c cgi-bin/xtabi
```

Run the Genelet framework tests from this checkout when the sibling `../perl`
repository is present:

```bash
prove -I../perl ../perl/Genelet/Test/*.t
```

Tabilet app tests are database-backed and are skipped by default. Enable them
only with a configured test database:

```bash
TABILET_RUN_APP_TESTS=1 prove -Ilib -I../perl lib/Tabilet/*/*.t
```

## Apache Example

```apache
Alias "/script" "/srv/tabilet/script"
<Directory /srv/tabilet/script/>
    SetHandler fcgid-script
    Options +ExecCGI
    Require all granted
</Directory>
```

The application should be deployed with a restricted script alias rather than a
global CGI handler for the whole document root.
