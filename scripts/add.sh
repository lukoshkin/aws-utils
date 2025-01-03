#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/init.sh"

function help_msg() {
  echo "Usage: $0 instance_id=<instance_id> [sshkey=<sshkey>] [user=<user>] [workdir=<workdir>]"
  echo "Register a new instance by adding a line to the maing.cfg"
  echo
  echo "Arguments:"
  echo "  instance_id - the instance ID"
  echo "  sshkey      - the SSH key to use"
  echo "  user        - the user to use for SSH connection"
  echo "  workdir     - the working directory on the instance"
  echo "  entrypoint  - the entrypoint cmd to run on the instance startup"
}

function register_instance() {
  IFS=$'\n' read -r -d '' -a content < <(utils::get_cfg_entry instance_opts)
  IFS='|' read -r -a headers <<<"${content[0]}"
  declare -A row

  if [[ -z ${headers[*]} ]]; then
    headers=("${INIT_CFG_COLUMNS[@]}")
    utils::set_cfg_entry instance_opts:- "$(
      IFS='|'
      echo "${headers[*]}"
    )"
  else
    init::check_headers "${headers[@]}" || return $?
  fi

  for ((pos = 1; pos <= ${#@}; pos++)); do
    if ! [[ ${!pos} =~ = ]]; then
      row[${headers[$pos - 1]}]=${!pos}
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

  for line in "${content[@]:1}"; do
    [[ $line =~ ${row[instance_id]} ]] && {
      utils::warn "Instance ${row[instance_id]} is already registered"
      utils::warn "To update it with 'add' command - delete the entry first"
      return
    }
  done

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
  for col in "${headers[@]}"; do
    local value=${row[$col]}
    [[ -n $value ]] && line+="$value|"
  done

  line=${line%|}
  utils::set_cfg_entry instance_opts:- "$line"
  line=${line//\\/}
  echo -e "$(utils::info "Successfully added the line:")" "$line"
  utils::info "Now you can run 'ec2 init'"
}

register_instance "$@"
