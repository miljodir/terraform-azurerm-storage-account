# Testing

This module is tested with the native [`terraform test`](https://developer.hashicorp.com/terraform/language/tests)
framework and OpenTofu's compatible native test command. Both run automatically
in GitHub Actions on every pull request to `main` (see
`.github/workflows/terraform-test.yaml`).

## What runs in CI

| Engine | Commands | Purpose |
| --- | --- | --- |
| Terraform | `terraform fmt`, `terraform init`, `terraform validate`, `terraform test` | Formatting, configuration validity and module behaviour |
| OpenTofu 1.13.9 | `tofu fmt`, `tofu init`, `tofu validate`, `tofu test` | The same checks using OpenTofu |

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

## Fixture coverage and limits

The synthetic network module returns only documentation-range IP addresses.
The tests verify how this module uses those outputs, but do **not** validate the
private module's implementation or its availability/access controls. The
prepare script changes only the disposable CI copy; it does not change the
module source used by consumers.

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

Requires Terraform >= 1.7 or a compatible OpenTofu release. Initializing the
unmodified configuration requires SSH access to the private module.

```sh
terraform init -backend=false
terraform test            # all tests
terraform test -verbose   # include plan output
terraform test -filter=tests/defaults.tftest.hcl
```

For credential-free local testing, use a disposable copy of the repository,
run `bash tests/fixtures/prepare.sh` from its root before initialization, and
copy `tests/overrides/storage_account_output_override.tf` into that copy's
root. Do not run the prepare script against a working checkout: it intentionally
replaces the private module source in `main.tf`.
