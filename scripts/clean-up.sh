#!/usr/bin/env bash

source "$(dirname "$0")/dot.sh"
source "$REPO_DIR/brave_utils.sh"
source "$LIB_DIR/aws-login.sh"
source "$LIB_DIR/pick.sh"

function clean_up() {
  declare -a _TARGET_OPTIONS
  declare -a _OTHER_OPTIONS
  brave::parse_one_option true -p --pick -- "$@" || return 1
  [[ ${#_OTHER_OPTIONS[@]} -gt 0 ]] && eval set "${_OTHER_OPTIONS[*]}"

  if [[ ${#_TARGET_OPTIONS[@]} -gt 0 ]]; then
    pk::pick "${_TARGET_OPTIONS[1]}"
  fi

  # shellcheck disable=SC2034
  EC2_CFG_FILE=$(utils::get_cfg_entry cfg_file)

  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)
  login::clean_up "$instance_id"
}

clean_up "$@"
