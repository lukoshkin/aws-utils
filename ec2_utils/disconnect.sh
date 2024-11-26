#!/usr/bin/env bash

source "$(dirname $0)/utils.sh"

disconnect() {
  local login_and_host
  login_and_host=$(utils::get_cfg_entry logstr)
  if [[ -n $login_and_host ]]; then
    declare -a aws_ssh_opts
    echo "Shutting down the instance on $login_and_host"
    aws_ssh_opts=(-i "$(utils::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")
    ssh "${aws_ssh_opts[@]}" "$login_and_host" "sudo shutdown -h now"
  else
    aws ec2 stop-instances --instance-ids "$(
      utils::get_cfg_entry instance_id "$HOME_LOGIN_CFG"
    )"
  fi
  if [[ -f $TMP_LOGIN_CFG ]]; then
    bash "$(dirname $0)/clean-up.sh"
    ## Remove when switch to per-instance tmp config
    # && rm "$TMP_LOGIN_CFG"
  fi
}

disconnect
