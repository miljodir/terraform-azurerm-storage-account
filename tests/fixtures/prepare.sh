#!/usr/bin/env bash
set -euo pipefail

module_file=main.tf
private_source='source = "git@github.com:miljodir/cp-shared.git//modules/public_nw_ips?ref=public_nw_ips/v1"'
fixture_source='source = "./tests/fixtures/network_vars"'

if [[ ! -f "$module_file" || ! -f tests/fixtures/network_vars/outputs.tf ]]; then
  echo "::error::The synthetic network module fixture is incomplete"
  exit 1
fi

matches=$(sed 's/^[[:space:]]*//' "$module_file" | grep -Fxc "$private_source" || true)
if [[ "$matches" != 1 ]]; then
  echo "::error::Expected exactly one private network module source in main.tf"
  exit 1
fi

sed -i "s|$private_source|$fixture_source|" "$module_file"
