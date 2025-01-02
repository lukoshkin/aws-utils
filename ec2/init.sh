#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
INIT_CFG_COLUMNS=(
  "instance_id"
  "sshkey"
  "user"
  "workdir"
  "entrypoint"
)

function init::check_columns() {
  sorted_headers=("$(printf "%s\n" "${@}" | sort)")
  sorted_columns=("$(printf "%s\n" "${INIT_CFG_COLUMNS[@]}" | sort)")
  [[ "${sorted_headers[*]}" = "${sorted_columns[*]}" ]] || {
    utils::error "Expected columns: ${INIT_CFG_COLUMNS[*]}"
    utils::error "Actual columns: $*"
    return 1
  }
}
