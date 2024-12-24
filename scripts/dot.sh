#!/bin/bash
## Common among all scripts settings
REPO_DIR=$(dirname "$(dirname "${BASH_SOURCE[0]}")")
SCRIPT_DIR="$REPO_DIR/scripts"
LIB_DIR="$REPO_DIR/ec2"
source "$REPO_DIR/brave_utils.sh"
source "$LIB_DIR/pick.sh"

if [[ -z ${_AWS_SSH_OPTS[*]} ]]; then
  _AWS_SSH_OPTS=("${AWS_SSH_OPTS[@]}")
fi

function dot::light_pick() {
  declare -a _TARGET_OPTIONS # declaring it here limits its usage
  ## However, we won't use anywhere outside this function.
  brave::parse_one_option true -p --pick -- "$@" || return $?
  brave::split_target_opt_value_by_comma

  [[ ${#_SPLIT_TARGET_OPTIONS[@]} -gt 1 ]] && return
  EC2_CFG_FILE=${EC2_CFG_FILE:-$(utils::get_cfg_entry cfg_file)}
  if [[ ${#_TARGET_OPTIONS[@]} -gt 0 || -z $EC2_CFG_FILE ]]; then
    EC2_CFG_FILE=$(pk::pick "${_TARGET_OPTIONS[1]}") || return $?
  fi
}

function dot::manage_multiple_instances() {
  if ! [[ $* =~ [[:space:]]--[[:space:]] ]]; then
    utils::error "Impl.error: '--' not provided."
    return 2
  fi

  local fn_name=$1
  shift

  declare -a checks
  while [[ $1 != -- ]]; do
    checks+=("$1")
    shift
  done
  shift

  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return $?
  eval set -- "${_OTHER_ARGS[*]}"

  for check in "${checks[@]}"; do
    $check || return $?
  done

  if [[ ${#_SPLIT_TARGET_OPTIONS[@]} -eq 0 ]]; then
    $fn_name "$@"
    return $?
  fi

  for ((i = 1; i < ${#_SPLIT_TARGET_OPTIONS[@]}; i = i + 2)); do
    EC2_CFG_FILE=$(pk::pick "${_SPLIT_TARGET_OPTIONS[i]}") || return $?
    $fn_name "$@"
  done
}
