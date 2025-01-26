#!/usr/bin/env bash

source "$(dirname "$0")/dot.sh"

function help_msg() {
  echo "Usage: ec2 set-up-user [-p=<instance_num>|--pick=<instance_num>] <username>"
  echo "Set up the user for the selected EC2 instance:"
  echo " - Create the user if it doesn't exist"
  echo " - Add the user to the sudo group"
  echo " - Add the SSH key to the user's authorized_keys"
  echo
  echo "Options:"
  echo "  -h, --help                Show this help message and exit"
  echo "  -p=<NUM>, --pick=<NUM>    Pick an instance number from the list"
}

function set_user() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return $?
  eval set -- "${_OTHER_ARGS[*]}"
  [[ ${#_OTHER_ARGS[@]} -gt 0 ]] && {
    local ec=0
    ## NOTE: parse_one_option from brave_utils.sh adds quotes ''
    if ! [[ ${_OTHER_ARGS[*]} =~ ^\'(-h|--help)\'$ ]]; then
      utils::error "Currently, no other than --pick arguments are supported."
      ec=2
    fi
    help_msg
    return $ec
  }

  local sshkey
  sshkey=$(utils::get_cfg_entry sshkey)
  sshkey=${sshkey/#\~/$HOME}
  [[ -z $sshkey ]] && {
    echo "No SSH key found in $EC2_CFG_FILE. Try first:"
    echo 'ec2 add instance_id=<instance_id> [sshkey=<sshkey>]'
    echo 'ec2 init'
    return 1
  }

  # shellcheck disable=SC2034
  EC2_USER=ubuntu
  utils::maybe_set_login_string
  export EC2_CFG_FILE EC2_USER LOGINSTR

  local authorized_keys public_key user=$1
  public_key=$(ssh-keygen -y -f "$sshkey")
  authorized_keys=/home/$user/.ssh/authorized_keys

  bash "$SCRIPT_DIR/execute.sh" -n "bash -s" <<<"
if ! id $user &>/dev/null; then
  sudo useradd -m -s /bin/bash $user
fi
sudo usermod -aG sudo $user
sudo mkdir -p /home/$user/.ssh
sudo chown -R $user:$user /home/$user/.ssh
sudo chmod 700 /home/$user/.ssh
if sudo grep -q '$public_key' '$authorized_keys'; then
  echo 'Key already exists in $authorized_keys'
else
  echo 'Adding key to $authorized_keys'
  echo '$public_key' | sudo tee -a '$authorized_keys'
fi
"
}

set_user "$@"
