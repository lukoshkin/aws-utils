#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/pick.sh"

pick() {
  [[ $# -gt 1 ]] && {
    echo "No more than one argument is allowed."
    return 1
  }

  local cfg_file
  cfg_file=$(pk::pick "$1") || return 1
  # shellcheck disable=SC2034
  EC2_CFG_FILE=

  utils::set_cfg_entry cfg_file "$cfg_file"
}

pick "$@"
