#!/bin/bash

source "$(dirname "$0")/new_utils.sh"
RESET="\033[0m"

_c() {
  local text=$1
  shift

  local fg=$1
  local ta=${2:-$_TEXT_ATTR}
  local bg=${3:-$_BG_COLOR}

  if [[ -n $bg ]]; then
    echo "\033[${ta:-0};${fg};${bg}m$text$RESET"
  fi
  echo "\033[${ta:-0};${fg}m$text$RESET"
}

function create_instance_map() {
  local instances
  instances=$(ls "$EC2_CFG_FOLDER" 2>/dev/null)
  [[ -z $instances ]] && {
    echo "No config found to set up a connection from!"
    echo "Check your 'instance_opts:-' key in ⤷"
    echo
    echo "❄️  $EC2_CFG_MAIN"
    echo
    echo "If it is OK, run 'ec2 init' to create configs"
    return 1
  }
  EC2_CFG_FILE=
  local current_cfg
  current_cfg=$(utils::get_cfg_entry cfg_file)

  while IFS='%' read -r num name iid; do
    local conn state selected=0 opt='  '
    EC2_CFG_FILE="$num%$name%$iid"
    conn=$(utils::get_cfg_entry connection)
    state=$(utils::get_cfg_entry state)

    [[ $EC2_CFG_FILE = "$current_cfg" ]] && {
      selected=9
      opt="*"
    }
    local state_sign
    case $state in
    running) state_sign=$(_c ● 32) ;;
    stopped) state_sign=$(_c ○ 33) ;;
    stopping) state_sign=$(_c ◐ 33) ;;
    pending) state_sign=$(_c ◑ 32) ;;
    *) ;;
    esac

    local _TEXT_ATTR=$selected
    case $conn in
    exists) name=$(_c "$name" 37) ;;
    active) name=$(_c "$name" 32) ;;
    broken) name=$(_c "$name" 31) ;;
    missing) name=$(_c "$name" 47 9) ;;
    *)
      >&2 echo "Unknown connection state: $conn"
      return 1
      ;;
    esac

    opt+="$name $state_sign"
    _INSTANCE_MAP[$opt]=$EC2_CFG_FILE
  done <<<"$instances"
}

function peek() {
  echo "Available instances:"
  local num=1
  for name in "${!_INSTANCE_MAP[@]}"; do
    echo -e "$((num++))) $name"
  done

  [[ "$1" = + ]] && echo "Select the one to connect to: "
}

function pk::pick() {
  local _choice choice=$1
  [[ -n $choice && $choice != = ]] && {
    choice=${choice#=}
    local _choice=$choice
    [[ $choice -ge 1 ]] && { _choice=$((choice - 1)); }
  }
  declare -A _INSTANCE_MAP
  declare -a names
  declare -a cfgs
  create_instance_map || return 1
  names=("${!_INSTANCE_MAP[@]}")
  [[ -n $_choice ]] && {
    cfgs=("${_INSTANCE_MAP[@]}")
    if [[ -n ${cfgs[$_choice]} ]]; then
      echo "${cfgs[$_choice]}"
      return 0
    else
      >&2 echo "No option found with the #'$choice'"
      >&2 peek
      return 1
    fi
  }
  read -rp "$(peek +)"
  if [[ -n ${names[$REPLY - 1]} ]]; then
    echo "${_INSTANCE_MAP[${names[$REPLY - 1]}]}"
    return 0
  else
    >&2 echo "Invalid selection"
    return 1
  fi
}

function pk::peek() {
  declare -A _INSTANCE_MAP
  create_instance_map || return 1
  peek
}
