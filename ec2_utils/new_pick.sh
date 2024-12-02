#!/bin/bash

source "$(dirname "$0")/new_utils.sh"

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

  while IFS=% read -r num name iid; do
    local conn state selected=0 opt='  '
    EC2_CFG_FILE="$num%$name%$iid"
    conn=$(utils::get_cfg_entry connection)
    state=$(utils::get_cfg_entry state)
    [[ $EC2_CFG_FILE = "$current_cfg" ]] && {
      selected=9
      opt="* "
    }
    local _TEXT_ATTR=$selected
    case $conn in
    exists) name=$(utils::c "$name" 37) ;;
    active) name=$(utils::c "$name" 32) ;;
    broken) name=$(utils::c "$name" 31) ;;
    blocked) name=$(utils::c "$name" 33) ;;
    missing) name=$(utils::c "$name" 47 9) ;;
    *)
      >&2 echo "Impl.error: Unknown connection state: $conn"
      return 1
      ;;
    esac

    opt+="$name"
    _INSTANCE_MAP[$opt]=$EC2_CFG_FILE
  done <<<"$instances"
}

function enrich_instance_map() {
  echo "Updating the context.."
  for name in "${!_INSTANCE_MAP[@]}"; do
    local instance_id state
    instance_id=$(cut -d% -f3 <<<"${_INSTANCE_MAP[$name]}") || {
      echo 'Impl.error: Improper file name format'
      return 2
    }
    state=$(
      aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].State.Name' \
        --output text
    ) || {
      echo "Failed to get the state of the instance: $instance_id"
      return 2
    }
    local state_sign
    case $state in
    running) state_sign=$(utils::c ● 32) ;;
    stopped) state_sign=$(utils::c ○ 33) ;;
    stopping) state_sign=$(utils::c ◐ 33) ;;
    pending) state_sign=$(utils::c ◑ 32) ;;
    *) ;;
    esac
    name+=" $state_sign"
    _ENRICHED_INSTANCE_MAP[$name]=${_INSTANCE_MAP[$name]}
  done
}

function peek() {
  local keymap prompt
  case $1 in
  *)
    [[ $# -gt 0 ]] && ! [[ $1 =~ ^(\+|\?|\+\?|\?\+)$ ]] && {
      echo "Impl.error: Invalid argument: <$1>"
      echo "Allowed ones: '?', '+', '?+', '+?'"
      return 1
    }
    keymap=("${!_INSTANCE_MAP[@]}")
    ;;&
  *\+*)
    declare -A _ENRICHED_INSTANCE_MAP
    enrich_instance_map
    keymap=("${!_ENRICHED_INSTANCE_MAP[@]}")
    ;;&
  *\?*) prompt="Select the one to connect to: " ;;
  esac

  local num=1
  echo -e "$(utils::c "Available instances:" 37 1)"
  for name in "${keymap[@]}"; do
    echo -e "$((num++))) $name"
  done
  [[ -n $prompt ]] && echo "$prompt"
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
      >&2 peek '+'
      return 1
    fi
  }
  read -rp "$(peek '?')"
  if [[ -n $REPLY && -n ${names[$REPLY - 1]} ]]; then
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
  peek '+'
}

# pk::peek
