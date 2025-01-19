#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

function help_msg() {
  echo "Usage: $0 [-p=<profile_num>|--pick=<profile_num>]"
  echo "Undo changes to AWS resources made by ec2."
}

function clean_up() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return $?
  [[ ${#_OTHER_ARGS[@]} -gt 0 ]] && {
    local ec=0
    if ! [[ ${_OTHER_ARGS[*]} =~ -h|--help ]]; then
      utils::error "Currently, no other than --pick arguments are supported."
      ec=2
    fi
    help_msg
    return $ec
  }
  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)
  login::clean_up "$instance_id"
}

dot::manage_multiple_instances clean_up -- "$@"
