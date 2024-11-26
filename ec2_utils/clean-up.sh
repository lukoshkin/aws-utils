#!/usr/bin/env bash

source "$(dirname "$0")/aws-login.sh"
source "$(dirname "$0")/utils.sh"

function clean_up() {
  local revoke_rule_uri
  echo "Searching the inbound rules added by ec2.."
  revoke_rule_uri=$(utils::get_cfg_entry revoke-rule-uri:-)
  [[ -z $revoke_rule_uri ]] && {
    echo "No rules found."
    return
  }
  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)
  [[ -z $instance_id ]] && { ## || "-p" is provided
    bash "$(dirname "$0")/pick.sh"
    instance_id=$(utils::get_cfg_entry instance_id)
  }
  local iid ip4 sg_id
  local found_any=false
  if [[ -n $revoke_rule_uri ]]; then
    while IFS='=' read -r iid ip4 sg_id; do
      [[ $iid != "$instance_id" ]] && continue
      login::revoke_ssh_inbound_rule "$sg_id" "$ip4"
      found_any=true
    done <<<"$revoke_rule_uri"
  fi
  if $found_any; then
    echo "Cleaned up!"
  fi
}

clean_up
