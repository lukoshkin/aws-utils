#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"

function register_instance() {
  IFS='|' read -r -a columns < <(utils::get_cfg_entry instance_opts | head -1)
  ## TODO: check if the content of the config table before adding an instance
  ## It may be already there
  declare -A row

  for ((pos = 1; pos <= ${#@}; pos++)); do
    if ! [[ ${!pos} =~ = ]]; then
      row[${columns[$pos - 1]}]=${!pos}
      continue
    fi
    IFS='=' read -r left right <<<"${!pos}"
    if [[ -z $left || -z $right ]]; then
      >&2 echo "Invalid argument: ${!pos}"
      return 1
    fi
    row[$left]=$right
  done

  if [[ -z ${row[instance_id]} ]]; then
    >&2 echo "Instance ID is required"
    return 1
  fi
  if [[ -z ${row[sshkey]} ]]; then
    declare -a keys
    keys=(~/.ssh/*.pem)
    if [[ ${#keys[@]} -eq 0 ]]; then
      >&2 echo "Specify SSH key to use"
      return 1
    fi
    PS3="Select the SSH key to use: "
    row[sshkey]=$(utils::select_option "${keys[@]}") || return 1
  fi

  local line
  row[sshkey]=${row[sshkey]//\//\\/}
  for col in "${columns[@]}"; do
    local value=${row[$col]}
    [[ -n $value ]] && line+="$value|"
  done
  # shellcheck disable=SC2034
  EC2_CFG_FILE= # just to make sure
  line=${line%|}
  utils::set_cfg_entry instance_opts:- "$line"
  line=${line//\\/}
  echo -e "$(utils::info "Successfully added the line:")" "$line"
  utils::info "Now you can run 'ec2 init'"
}

register_instance "$@"
