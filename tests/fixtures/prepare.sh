#!/usr/bin/env bash
set -euo pipefail

module_file=main.tf
private_source='source = "git@github.com:miljodir/cp-shared.git//modules/public_nw_ips?ref=public_nw_ips/v1"'
fixture_source='source = "./tests/fixtures/network_vars"'

if [[ ! -f "$module_file" || ! -f tests/fixtures/network_vars/outputs.tf ]]; then
  echo "::error::The synthetic network module fixture is incomplete"
  exit 1
fi

prepared_file="${module_file}.prepare.tmp.$$"
if ! awk -v expected="$private_source" -v replacement="$fixture_source" '
  {
    line = $0
    sub(/^[[:space:]]*/, "", line)
    if (line == expected) {
      indentation = substr($0, 1, length($0) - length(line))
      print indentation replacement
      matches++
    } else {
      print
    }
  }
  END {
    if (matches != 1) {
      exit 1
    }
  }
' "$module_file" > "$prepared_file"; then
  rm -f "$prepared_file"
  echo "::error::Expected exactly one private network module source in main.tf"
  exit 1
fi

mv -- "$prepared_file" "$module_file"
