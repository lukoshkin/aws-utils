#!/bin/bash
## Common among all scripts settings
REPO_DIR=$(dirname "$(dirname "${BASH_SOURCE[0]}")")
LIB_DIR="$REPO_DIR/ec2"
source "$REPO_DIR/brave_utils.sh"
source "$LIB_DIR/pick.sh"

function dot::light_pick() {
  declare -a _TARGET_OPTIONS
  brave::parse_one_option true -p --pick -- "$@" || return 1
  EC2_CFG_FILE=$(utils::get_cfg_entry cfg_file)
  if [[ ${#_TARGET_OPTIONS[@]} -gt 0 || -z $EC2_CFG_FILE ]]; then
    EC2_CFG_FILE=$(pk::pick "${_TARGET_OPTIONS[1]}") || return 1
    # shellcheck disable=SC2034
  fi
}
