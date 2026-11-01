# actions

Reusable GitHub Actions shared by AprilNEA's repositories. Pin them by
commit SHA, with the version as a comment:

```yaml
- uses: AprilNEA/actions/op-environment@<sha> # v1.0.0
```

## `op-environment`

Exports the variables of a [1Password Environment](https://developer.1password.com/environments)
to the job's later steps (`GITHUB_ENV`), each value masked. It authenticates
with a [service account](https://developer.1password.com/docs/service-accounts)
scoped to that Environment, so no vault or `op://` item reference is
involved; the Environment ID is not a secret and can live in a repository
variable.

```yaml
- uses: AprilNEA/actions/op-environment@<sha> # v1.0.0
  with:
    service-account-token: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    environment-id: ${{ vars.OP_RELEASE_ENVIRONMENT_ID }}
    # Optional: export only names starting with one of these.
    prefixes: APPLE_ AZURE_
- run: codesign --sign "$APPLE_SIGNING_IDENTITY" …
```

| Input | Required | Default | Purpose |
|---|---|---|---|
| `service-account-token` | yes | | Token of a service account that can read the Environment |
| `environment-id` | yes | | The Environment's ID (1Password app → Developer → View Environments → Manage environment → Copy environment ID) |
| `prefixes` | no | all | Whitespace-separated name prefixes to export |
| `cli-version` | no | `2.41.1` | 1Password CLI to install; `op run --environment` needs ≥ 2.41.0 |

How it works: the action installs the 1Password CLI, snapshots the
digests of the step's environment, runs `op run --environment <id>`, and the
child exports every variable that is new or changed, after printing an
`::add-mask::` for each line of its value. A variable of the Environment that
shares its name with one already in the runner's environment is exported
too, since its value differs; one whose value is identical is not.

The variables land in the environment of every later step, including
third-party actions. Scope them with `prefixes` when a job needs only some,
and keep one Environment per trust boundary: a service account reads whole
Environments, so the Environment is the unit of access, and a GitHub
[environment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
with its own `OP_SERVICE_ACCOUNT_TOKEN` is where the token for a sensitive
one belongs.

## `github-app-token`

Mints a GitHub App installation token from the App's client ID and private
key, where the key may be the base64 of the PEM (the form that survives a
paste into a secret store). Pairs with `op-environment`:

```yaml
- uses: AprilNEA/actions/op-environment@<sha> # v1.0.0
  with:
    service-account-token: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    environment-id: ${{ vars.OP_AUTOMATION_ENVIRONMENT_ID }}
    prefixes: GITHUB_APP_
- id: app
  uses: AprilNEA/actions/github-app-token@<sha> # v1.0.0
  with:
    client-id: ${{ env.GITHUB_APP_ID }}
    private-key: ${{ env.GITHUB_APP_PRIVATE_KEY }}
    # Optional, for a token on another owner's repositories:
    owner: some-org
    repositories: repo-a,repo-b
- run: gh pr create …
  env:
    GH_TOKEN: ${{ steps.app.outputs.token }}
```

| Input | Required | Purpose |
|---|---|---|
| `client-id` | yes | The App's client ID or numeric App ID |
| `private-key` | yes | The PEM, or its base64 (whitespace ignored) |
| `owner` | no | Owner for a cross-repository token |
| `repositories` | no | Comma- or newline-separated repositories for a cross-repository token |

Output `token` is the installation token. Each PEM line is masked before the
key is handed to `actions/create-github-app-token`.

## Development

`op-environment/test.sh` runs the two scripts with a stand-in `op`; CI runs
it on Linux, macOS and Windows, plus `actionlint`, `shellcheck` and `shfmt`.

## License

MIT.
