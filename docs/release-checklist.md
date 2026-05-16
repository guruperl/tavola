# Release Checklist

Before tagging a Tavola release:

- Run `GOWORK=off go test ./...`.
- Run `GOWORK=off go vet ./...`.
- Run `GOWORK=off go test -race ./...`.
- Run `GOWORK=off staticcheck ./...`.
- Run `script/smoke-generated-project --spec specs/project.template.json --lang all --no-web-ui`.
- Run `script/smoke-sqlite-init`.
- Confirm generated Go archives require the current released Genelet module.

## Module Path

The module currently remains `github.com/guruperl/tavola` because the repository
remote is `guruperl/tavola`. Do not rename the module to
`github.com/genelet/tavola` as a standalone code change. Move the repository,
then update `go.mod`, internal imports, docs, and downstream consumers in the
same migration.
