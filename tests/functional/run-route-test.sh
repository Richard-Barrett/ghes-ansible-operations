#!/usr/bin/env bash
set -euo pipefail

case_name=${1:?Usage: run-route-test.sh CASE_NAME success|failure}
expected_result=${2:?Usage: run-route-test.sh CASE_NAME success|failure}
test_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "${test_root}/../.." && pwd)
call_log=$(mktemp "${TMPDIR:-/tmp}/ghes-route-test.XXXXXX")
ansible_playbook=${ANSIBLE_PLAYBOOK:-ansible-playbook}
if [[ -x "${repository_root}/.venv/bin/ansible-playbook" ]]; then
  ansible_playbook="${repository_root}/.venv/bin/ansible-playbook"
fi
rm -f "${call_log}"
trap 'rm -f "${call_log}"' EXIT

export ANSIBLE_ROLES_PATH="${test_root}/roles"
export ANSIBLE_HOME="${repository_root}/.ansible"
export ANSIBLE_LOCAL_TEMP="${repository_root}/.ansible/tmp"

set +e
"${ansible_playbook}" \
  -i "${test_root}/inventory.yml" \
  "${repository_root}/playbooks/upgrade-route.yml" \
  --extra-vars "@${test_root}/cases/${case_name}.yml" \
  --extra-vars "ghes_upgrade_route_call_log=${call_log}"
result=$?
set -e

if [[ "${expected_result}" == "failure" ]]; then
  if [[ ${result} -eq 0 ]]; then
    echo "Expected ${case_name} to fail, but it succeeded" >&2
    exit 1
  fi
  if [[ -e "${call_log}" ]]; then
    echo "Invalid route invoked the upgrade role" >&2
    exit 1
  fi
  exit 0
fi

if [[ "${expected_result}" != "success" ]]; then
  echo "Expected result must be success or failure" >&2
  exit 2
fi

if [[ ${result} -ne 0 ]]; then
  echo "Expected ${case_name} to succeed, but it failed" >&2
  exit "${result}"
fi

diff -u "${test_root}/expected/${case_name}.txt" "${call_log}"
