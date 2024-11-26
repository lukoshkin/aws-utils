#!/usr/bin/env bash

source "$(dirname "$0")/utils.sh"

function select_instance() {
  local raw_instance_ids
  raw_instance_ids=$(utils::get_cfg_entry instance_ids "$HOME_LOGIN_CFG")
  [[ -z ${raw_instance_ids[*]} ]] && {
    echo "No instances to select from"
    echo "Check your 'instance_ids:-' key in $HOME_LOGIN_CFG"
    return 1
  }

  _cache_values() {
    local instance_id=$1 sshkey=$2
    utils::set_cfg_entry instance_id "$instance_id"
    utils::set_cfg_entry sshkey "$sshkey"
    utils::set_cfg_entry logstr
  }

  local _choice choice=$1
  [[ -n $choice && $choice != = ]] && {
    choice=${choice#=}
    local _choice=$choice
    [[ $choice -ge 1 ]] && { _choice=$((choice - 1)); }
  }
  declare -a _instance_ids
  declare -a _ssh_keys
  local invalid_choice=false
  while IFS='=' read -r iid pem_file; do
    [[ -z $pem_file ]] && continue
    _instance_ids+=("$iid")
    _ssh_keys+=("$pem_file")
  done <<<"$raw_instance_ids"
  [[ -n $_choice ]] && {
    if [[ -n ${_instance_ids[$_choice]} ]]; then
      _cache_values "${_instance_ids[$_choice]}" "${_ssh_keys[$_choice]}"
      return 0
    else
      invalid_choice=true
    fi
  }

  declare -A instance_ids
  declare -A ssh_keys
  declare -a names
  for ((i = 0; i < ${#_instance_ids[@]}; i++)); do
    local iname
    iname=$(
      aws ec2 describe-instances \
        --instance-ids "${_instance_ids[$i]}" \
        --query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
        --output text
    )
    ssh_keys["$iname"]="${_ssh_keys[$i]}"
    instance_ids["$iname"]="${_instance_ids[$i]}"
    names+=("$iname")
  done

  if $invalid_choice; then
    echo "No option found with the #'$choice'"
    echo "Available instances:"
    local num=1
    for iname in "${names[@]}"; do
      echo "$num) $iname"
      ((num++))
    done
    return 1
  fi
  echo "Select an instance to continue with:"
  choice=$(utils::select_option "${names[@]}") || {
    echo "Invalid selection"
    return 1
  }
  _cache_values "${instance_ids[$choice]}" "${ssh_keys[$choice]}"
}

if [[ $# -gt 1 ]]; then
  echo "Usage: $(realpath --relative-to "$PWD" "$0") [choice]"
  echo
  echo "The 'choice' argument is the index of the instance to pick"
  echo "If not provided, a prompt will be shown to select an instance"
  exit 1
fi

select_instance "$1"
