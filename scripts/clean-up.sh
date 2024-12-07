#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

help_msg() {
  echo "Usage: $0 [-p=<profile_num>|--pick=<profile_num>]"
  echo "Undo changes to AWS resources made by ec2."
}

function clean_up() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return 1
  [[ ${#_OTHER_ARGS[@]} -gt 0 ]] && {
    >&2 echo "Currently, no other than --pick arguments are supported."
    help_msg
    return 1
  }
  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)
  login::clean_up "$instance_id"
}

clean_up "$@"
