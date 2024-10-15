#!/bin/bash

source "$(dirname $0)/login.sh"

disconnect() {
  local login_and_host
  login_and_host=$(login::get_cfg_entry logstr)
  if [[ -n $login_and_host ]]; then
    echo "Shutting down the instance on $login_and_host"
    ssh "${AWS_SSH_OPTS[@]}" "$login_and_host" "sudo shutdown -h now"
    rm "$TMP_LOGIN_CFG"
  else
    aws ec2 stop-instances --instance-ids "$(login::get_cfg_entry instance_id)"
  fi
}

disconnect
