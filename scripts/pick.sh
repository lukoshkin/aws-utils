#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"

help_msg() {
  echo 'Usage: pick <INSTANCE_NUM_IN_EC2_LS>'
  echo "Pick an instance from the list of instances in the \$(ec2 ls) list."
}

pick() {
  [[ $# -gt 1 ]] && {
    echo "No more than one argument is allowed."
    help_msg
    return 2
  }
  local cfg_file
  cfg_file=$(pk::pick "$1") || return $?
  # shellcheck disable=SC2034
  EC2_CFG_FILE=
  utils::set_cfg_entry cfg_file "$cfg_file"
}

pick "$@"
