# Testing

This module is tested with the native [`terraform test`](https://developer.hashicorp.com/terraform/language/tests)
framework and OpenTofu's compatible native test command. Both run automatically
in GitHub Actions on pull requests targeting any branch, on pushes to `main`,
and when manually dispatched (see `.github/workflows/terraform-test.yaml`).

## What runs in CI

| Engine | Commands | Purpose |
| --- | --- | --- |
| Terraform | `terraform fmt`, `terraform init`, `terraform validate`, `terraform test` | Formatting, configuration validity and module behaviour |
| OpenTofu latest stable 1.x | `tofu fmt`, `tofu init`, `tofu validate`, `tofu test` | The same checks using OpenTofu |

CI selects OpenTofu with the floating `1.x` version range, rather than a fixed
release. OpenTofu 1.13.9 is a verified release for the local commands below;
each CI run reports the version actually selected.

## How the tests work

- Test files live in `tests/` and end in `.tftest.hcl`.
- Every test file declares `mock_provider` blocks. Mocked providers never call
  Azure: no credentials are needed and **no real resources are created**.
  Resource attributes that Azure would compute (for example `id`) get generated
  fake values.
- Each `run` block plans (`command = plan`) or "applies" against the mocks
  (`command = apply`) with a set of input variables, then checks the result with
  `assert` blocks.
- Input validation is tested with `expect_failures`, which passes only when the
  listed variable validation or precondition fails.
- Data sources and nested modules that would need real lookups can be replaced
  with `override_data` / `override_module`.
- This module references a private Git SSH module. CI runs in a disposable copy
  and `tests/fixtures/prepare.sh` substitutes a small synthetic module so
  initialization does not require SSH credentials.

- When tests run, the module is the *root* module. Terraform then rejects
  outputs that contain sensitive attributes unless they are marked
  `sensitive = true` (consumers calling the module are not affected). Put
  test-only override files in `tests/overrides/` named `*_override.tf`, e.g.

  ```hcl
  output "storage_account" {
    sensitive = true
  }
  ```

  The shared workflow copies them into its disposable module copy before
  OpenTofu validation and before either engine runs tests. Terraform validation
  runs before the output override is copied; OpenTofu validation runs with the
  override because it rejects the sensitive output otherwise.

These are unit-style tests: they verify how the module turns inputs into
resource configuration. They do not prove that Azure accepts the configuration;
that still happens when a consuming workload runs `terraform plan`/`apply`.

Firewall regression runs apply Deny and then Allow against the same mock state,
check the reverse plan, and cover the AzureRM `Allow`/`AzureServices`/no-exceptions
refresh special case. Separate runs preserve other bypass combinations and each
kind of exception, including synthetic known public IPs. Mocks do not execute
AzureRM's expand/flatten functions or refresh from Azure, so these runs cannot
prove a drift-free live apply. The normalization is based on the provider's
[`flattenAccountNetworkRules` implementation](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.67.0/internal/services/storage/storage_account_helpers_network.go#L36-L66),
not an assumption that Azure discards bypass or exception lists under Allow.

## Fixture coverage and limits

The synthetic network module returns only documentation-range IP addresses.
The tests verify how this module uses those outputs, but do **not** validate the
private module's implementation or its availability/access controls. The
prepare script changes only the disposable CI copy; it does not change the
module source used by consumers.

The separate `fixture-guard` CI job runs `bash tests/fixtures/test-prepare.sh`.
It exercises the actual preparation script in disposable synthetic copies,
checking exact substitution, unchanged similar/commented decoys, and rejection
of changed or duplicated sources without modifying the input file.

## Release workflow events

The separate `tag-module.yaml` workflow previews releases on opened, updated,
reopened, and relabeled pull requests to `main` that change `**.tf` files.
It also runs on closed pull requests with the same branch and path filters,
but calls the shared metadata workflow only when the pull request was merged.
An unmerged close does not generate metadata or dispatch a release.

The shared `generate-release-metadata/v1` workflow supports merged
`pull_request` events. A merged change with a release label and releasable
module files dispatches `create_release` and `update_wiki`; the existing
repository-dispatch jobs consume those events. The `no-release` label or no
releasable module changes suppresses release dispatch. Workflow-only changes
do not match the Terraform path filter. Re-running a merged-event workflow
can dispatch again; this migration does not add release idempotency.

The caller grants write permissions only to the jobs that require them and
does not check out pull request code itself. Public-fork `pull_request` runs
have a read-only token: release-plan comments and merged-event release
dispatches requiring write access cannot be relied on for fork contributions.
No elevated fork-token workaround is provided by this workflow.

## Writing a test

```hcl
mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-test"
}

run "defaults" {
  command = plan

  assert {
    condition     = azurerm_example.this.name == "expected"
    error_message = "Name should default to 'expected'."
  }
}

run "rejects_invalid_input" {
  command = plan

  variables {
    some_setting = "not-allowed"
  }

  expect_failures = [var.some_setting]
}
```

Guidelines:

- Add or update a test whenever you change behaviour, defaults or validation.
- Use obviously fake values (`rg-test`, `00000000-0000-0000-0000-000000000000`,
  documentation IP ranges such as `192.0.2.0/24`). Never use real subscription
  IDs, tenant IDs, names or addresses — this repository is public.
- Prefer one behaviour per `run` block with a descriptive name.

## Running locally

The following commands require Bash, Git, `tar`, and Terraform >= 1.7 or
OpenTofu (verified with 1.13.9). They use mocked providers and a synthetic
dependency, so no Azure credentials or private-module SSH access are needed.

Run either complete example from the repository root. Each creates a separate
disposable copy of the **committed** `HEAD`; uncommitted changes are not included.
The parentheses isolate shell options, variables and directory changes from
your interactive shell. The disposable copy is removed when the example exits.
Do not run the prepare script in a working checkout: it changes `main.tf`.

For Terraform, validate before copying the test-only output override:

```bash
(
  set -euo pipefail
  test_dir="$(mktemp -d)"
  trap 'rm -rf -- "$test_dir"' EXIT
  git archive HEAD | tar -x -C "$test_dir"
  cd "$test_dir"
  bash tests/fixtures/prepare.sh
  test_file='tests/storage_account.tftest.hcl'
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) test_file='tests\storage_account.tftest.hcl' ;;
  esac
  terraform init -backend=false -no-color
  terraform validate -no-color
  cp tests/overrides/storage_account_output_override.tf .
  terraform test -no-color "-filter=$test_file"
)
```

For OpenTofu, copy the output override before validation:

```bash
(
  set -euo pipefail
  test_dir="$(mktemp -d)"
  trap 'rm -rf -- "$test_dir"' EXIT
  git archive HEAD | tar -x -C "$test_dir"
  cd "$test_dir"
  bash tests/fixtures/prepare.sh
  test_file='tests/storage_account.tftest.hcl'
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) test_file='tests\storage_account.tftest.hcl' ;;
  esac
  tofu init -backend=false -no-color
  cp tests/overrides/storage_account_output_override.tf .
  tofu validate -no-color
  tofu test -no-color "-filter=$test_file"
)
```

Confirm the summary reports passing runs; `Success! 0 passed, 0 failed` does
not mean the tests ran. Omit `-filter` to run all test files, or add `-verbose`
for plan output. The fixture and output override apply only to the disposable
copy and have the coverage limitations described above.
