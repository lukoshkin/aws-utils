#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

function is_number() {
  [[ $1 =~ ^[0-9]+$ ]] || {
    utils::error "Invalid input: <$1>"
    return 2
  }
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

  declare -A num_opt_map
  declare -A opt_cfg_map
  while IFS=% read -r num name iid; do
    local conn state selected=0 opt='  '
    EC2_CFG_FILE="$num%$name%$iid"
    conn=$(utils::get_cfg_entry connection)
    state=$(utils::get_cfg_entry state)
    [[ $EC2_CFG_FILE = "$current_cfg" ]] && {
      selected=1
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
      utils::error "Impl.error: Unknown connection state: $conn"
      return 2
      ;;
    esac

    opt+="$name"
    num_opt_map[$num]=$opt
    opt_cfg_map[$opt]=$EC2_CFG_FILE
  done <<<"$instances"
  for i in "${!num_opt_map[@]}"; do
    _PICK_OPTS+=("${num_opt_map[$i]}")
    _PICK_CFGS+=("${opt_cfg_map["${num_opt_map[$i]}"]}")
  done
}

function enrich_instance_map() {
  echo "Scrapping the latest data.."
  for ((i = 0; i < ${#_PICK_CFGS[@]}; i++)); do
    local name instance_id state
    instance_id=${_PICK_CFGS[i]##*%}
    name=${_PICK_OPTS[i]}
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
    _PEEK_OPTS+=("$name")
  done
}

function peek() {
  local prompt
  declare -a opts
  case $1 in
  *)
    [[ $# -gt 0 ]] && ! [[ $1 =~ ^(\+|\?|\+\?|\?\+)$ ]] && {
      echo "Impl.error: Invalid argument: <$1>"
      echo "Allowed ones: '?', '+', '?+', '+?'"
      return 2
    }
    opts=("${_PICK_OPTS[@]}")
    ;;&
  *\+*)
    declare -a _PEEK_OPTS
    enrich_instance_map
    opts=("${_PEEK_OPTS[@]}")
    ;;&
  *\?*) prompt="Select the one to continue with: " ;;
  esac

  local num=1
  echo -e "$(utils::c "Available instances:" 37 1)"
  for ((i = 0; i < ${#opts[@]}; i++)); do
    echo -e "$((i + 1))) ${opts[i]}"
  done
  if [[ -n $prompt ]]; then
    echo "$prompt"
  fi
}

function pk::pick() {
  local _choice choice=$1
  [[ -n $choice && $choice != = ]] && {
    choice=${choice#=}
    _choice=$choice
    if [[ -n $choice ]]; then
      is_number "$choice" || return $?
      [[ $choice -ge 1 ]] && { _choice=$((choice - 1)); }
    fi
  }
  declare -a _PICK_OPTS=() _PICK_CFGS=()
  create_instance_map || return $?
  [[ -n $_choice ]] && {
    if [[ -n ${_PICK_CFGS[$_choice]} ]]; then
      echo "${_PICK_CFGS[$_choice]}"
      return
    else
      utils::error "No option found with the #'$choice'"
      >&2 peek '+'
      return 1
    fi
  }
  read -rp "$(peek '?')"
  is_number "$REPLY" || return $?
  if [[ -n $REPLY && -n ${_PICK_CFGS[REPLY - 1]} ]]; then
    echo "${_PICK_CFGS[REPLY - 1]}"
    return
  else
    utils::error "Invalid selection"
    return 1
  fi
}

function pk::peek() {
  declare -A _INSTANCE_MAP
  create_instance_map || return $?
  peek '+'
}
