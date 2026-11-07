#!/usr/bin/env bash
set -euo pipefail

fixture_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_directory="$(mktemp -d)"
trap 'rm -rf -- "$test_directory"' EXIT

mkdir -p "$test_directory/tests/fixtures/network_vars"
cp "$fixture_directory/network_vars/outputs.tf" "$test_directory/tests/fixtures/network_vars/"
cd "$test_directory"

source_line='  source = "git@github.com:miljodir/cp-shared.git//modules/public_nw_ips?ref=public_nw_ips/v1"'
replacement_line='  source = "./tests/fixtures/network_vars"'
similar_line='  source = "git@githubXcom:miljodir/cp-sharedXgit//modules/public_nw_ips?ref=public_nw_ips/v1"'
comment_line="# $source_line"

printf '%s\n' 'module "network_vars" {' "$source_line" '}' "$similar_line" "$comment_line" > main.tf
printf '%s\n' 'module "network_vars" {' "$replacement_line" '}' "$similar_line" "$comment_line" > expected.tf
bash "$fixture_directory/prepare.sh"
if ! cmp -s main.tf expected.tf; then
  echo "::error::Exact source substitution changed indentation, decoys, or comments"
  exit 1
fi
echo "PASS: exact substitution preserves similar and commented decoys"

expect_rejection() {
  local case_name="$1"
  cp main.tf before.tf
  if bash "$fixture_directory/prepare.sh" > rejection.log 2>&1; then
    echo "::error::$case_name was accepted"
    exit 1
  fi
  if ! grep -Fxq "::error::Expected exactly one private network module source in main.tf" rejection.log; then
    cat rejection.log
    echo "::error::$case_name failed for an unexpected reason"
    exit 1
  fi
  if ! cmp -s main.tf before.tf; then
    echo "::error::$case_name modified main.tf on rejection"
    exit 1
  fi
  echo "PASS: $case_name is rejected without mutation"
}

printf '%s\n' 'module "network_vars" {' "${source_line/v1/v2}" '}' > main.tf
expect_rejection "changed source ref"

printf '%s\n' 'module "network_vars" {' "$similar_line" '}' > main.tf
expect_rejection "changed source URL"

printf '%s\n' 'module "network_vars" {' "$source_line" "$source_line" '}' > main.tf
expect_rejection "duplicate source"
