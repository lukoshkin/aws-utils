#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"

function help_msg() {
  echo "Usage: $0 instance_id=<instance_id> [sshkey=<sshkey>] [user=<user>] [workdir=<workdir>]"
  echo "Register a new instance by adding a line to the maing.cfg"
  echo
  echo "Arguments:"
  echo "  instance_id - the instance ID"
  echo "  sshkey      - the SSH key to use"
  echo "  user        - the user to use for SSH connection"
  echo "  workdir     - the working directory on the instance"
}

function register_instance() {
  IFS='|' read -r -a columns < <(utils::get_cfg_entry instance_opts | head -1)
  ## TODO: check the content of the config table before adding an instance
  ## The instance may be already there
  declare -A row

  for ((pos = 1; pos <= ${#@}; pos++)); do
    if ! [[ ${!pos} =~ = ]]; then
      row[${columns[$pos - 1]}]=${!pos}
      continue
    fi
    IFS='=' read -r left right <<<"${!pos}"
    if [[ -z $left || -z $right ]]; then
      utils::error "Invalid argument: ${!pos}"
      return 2
    fi
    row[$left]=$right
  done

  if [[ -z ${row[instance_id]} ]]; then
    utils::error "Instance ID is required"
    return 2
  fi

  utils::valid_instance_id_check "${row[instance_id]}" || {
    help_msg
    return $?
  }

  if [[ -z ${row[sshkey]} ]]; then
    declare -a keys
    keys=(~/.ssh/*.pem)
    if [[ ${#keys[@]} -eq 0 ]]; then
      utils::error "Specify SSH key to use"
      return 2
    fi
    PS3="Select the SSH key to use: "
    row[sshkey]=$(utils::select_option "${keys[@]}") || return $?
  else
    [[ -f ${row[sshkey]} ]] || {
      echo "File not found: ${row[sshkey]}"
      echo "Make sure you have a corresponding SSH key file for the instance to add"
      return 2
    }
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
