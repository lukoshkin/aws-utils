#!/bin/bash

source "$(dirname $0)/login.sh"

disconnect() {
  local login_and_host
  login_and_host=$(login::get_cfg_entry logstr)
  if [[ -n $login_and_host ]]; then
    declare -a aws_ssh_opts
    echo "Shutting down the instance on $login_and_host"
    aws_ssh_opts=(-i "$(login::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")
    ssh "${aws_ssh_opts[@]}" "$login_and_host" "sudo shutdown -h now"
  else
    aws ec2 stop-instances --instance-ids "$(
      login::get_cfg_entry instance_id "$HOME_LOGIN_CFG"
    )"
  fi
  local revoke_rule_uri ip4 sg_id
  revoke_rule_uri=$(login::get_cfg_entry revoke-rule-uri)
  if [[ -n $revoke_rule_uri ]]; then
    ip4=$(cut -d% -f1 <<<"$revoke_rule_uri")
    sg_id=$(cut -d% -f2 <<<"$revoke_rule_uri")
    login::revoke_ssh_inbound_rule "$sg_id" "$ip4"
  fi
  rm -f "$TMP_LOGIN_CFG"
}

disconnect
