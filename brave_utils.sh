#!/bin/bash

set_if_new() {
  local opt_name=$1 set_value=$2
  if [[ -n ${!opt_name} ]]; then
    >&2 echo "Expected no more than one $opt_name"
    >&2 echo "You passed: ${!opt_name} and $set_value"
    return 2
  fi
  echo "$set_value"
}

brave::parse_one_option() {
  local short_target long_target opt_with_value
  while [[ $1 != -- ]]; do
    case $1 in
    --*) long_target=$(set_if_new long_target "$1") || return $? ;;&
    -?)
      short_target=$(set_if_new short_target "$1") || return $?
      [[ ${#short_target} -eq 1 ]] && {
        >&2 echo "Expected a one symbol option"
        return 2
      }
      ;;&
    [^-]*)
      if [[ $1 =~ true|false ]]; then
        opt_with_value=$(set_if_new opt_with_value "$1") || return $?
      else
        >&2 echo "Invalid argument: <$1>"
        >&2 echo "Expected: -short|--long|true|false"
        return 2
      fi
      ;;&
    *) shift ;;
    esac
  done
  shift

  local pat
  if $opt_with_value && ${NO_INVALID_CHECKS:=false}; then
    pat="-[a-zA-Z]*${short_target#-}"
    if [[ -n $long_target ]]; then
      pat="($pat|$long_target)"
    fi
  else
    pat="-[a-zA-Z]*${short_target#-}[a-zA-Z]*"
    if [[ -n $long_target ]]; then
      pat="($pat|$long_target)"
    fi
  fi
  if ! $NO_INVALID_CHECKS || $opt_with_value; then
    pat="^$pat(=.*)?$"
  else
    pat="^$pat$"
  fi
  for ((i = 1; i <= $#; )); do
    local arg=${!i}
    if [[ $arg =~ $pat ]]; then
      _TARGET_OPTIONS+=("$long_target")
      if $opt_with_value; then
        if [[ $arg =~ ^$long_target=? ]]; then
          if [[ $arg =~ = ]]; then
            _TARGET_OPTIONS+=("$(cut -d= -f2- <<<"$arg")")
            ((i++))
          else
            local next_arg=$((++i))
            [[ $i -le $# ]] || {
              >&2 echo "Option $long_target requires a value"
              return 2
            }
            _TARGET_OPTIONS+=("${!next_arg}")
          fi
          continue
        fi
        IFS='=' read -r left right <<<"$arg"
        IFS=${short_target#-} read -r left1 left2 <<<"$left"
        if [[ -n $left2 ]]; then
          >&2 echo "Option $short_target requires a value"
          >&2 echo "You passed it like $arg"
          return 2
        fi
        if [[ -n ${left1#-} ]]; then
          _OTHER_ARGS+=("$left1")
        fi
        if [[ -n $right || $arg =~ = ]]; then
          _TARGET_OPTIONS+=("$right")
        else
          local next_arg=$((++i))
          [[ $next_arg -ge $# || ${!next_arg} =~ ^-.* ]] && {
            >&2 echo "Option $short_target requires a value"
            return 2
          }
          _TARGET_OPTIONS+=("${!next_arg}")
        fi
      else
        _TARGET_OPTIONS+=("$arg")
      fi
    else
      _OTHER_ARGS+=("'$arg'")
    fi
    ((i++))
  done
}

brave::split_target_opt_value_by_comma() {
  if ((${#_TARGET_OPTIONS[@]} % 2 != 0)); then
    utils::error "The option requires a value!"
    exit 2
  fi
  _SPLIT_TARGET_OPTIONS=()
  for ((i = 0; i < ${#_TARGET_OPTIONS[@]}; i += 2)); do
    local target=${_TARGET_OPTIONS[i]} value=${_TARGET_OPTIONS[i + 1]}
    if [[ $value =~ , ]]; then
      IFS=, read -r -a values <<<"$value"
      for part in "${values[@]}"; do
        _SPLIT_TARGET_OPTIONS+=("$target" "$part")
      done
    else
      _SPLIT_TARGET_OPTIONS+=("$target" "$value")
    fi
  done
}

test_brave_utils() {
  echo "Testing the 'brave::parse_one_option' function"
  declare -a _TARGET_OPTIONS=() _OTHER_ARGS=()
  brave::parse_one_option "$@"
  echo '***'

  local opt_with_arg=false
  for arg in "$@"; do
    [[ $arg = '--' ]] && break
    [[ $arg = true ]] && opt_with_arg=true
  done

  if $opt_with_arg; then
    echo "Target options:"
    for ((i = 0; i < ${#_TARGET_OPTIONS[@]}; i += 2)); do
      echo "${_TARGET_OPTIONS[i]}=<${_TARGET_OPTIONS[i + 1]}>"
    done
  else
    echo "Target options: ${_TARGET_OPTIONS[*]}"
  fi
  echo
  echo "Other args: ${_OTHER_ARGS[*]}"

  if [[ $* =~ , ]]; then
    brave::split_target_opt_value_by_comma
    echo "Split target options:"
    for ((i = 0; i < ${#_SPLIT_TARGET_OPTIONS[@]}; i += 2)); do
      echo "${_SPLIT_TARGET_OPTIONS[i]}=<${_SPLIT_TARGET_OPTIONS[i + 1]}>"
    done
  fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  test_brave_utils "$@"
fi
