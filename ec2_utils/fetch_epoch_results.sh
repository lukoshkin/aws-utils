#!/bin/bash

source "$(dirname "$0")/login.sh"

function fetch_images() {
  local fid=$1
  local fid_prefix=/home/$EC2_USER/assets/${TASK:-detector}/single_run
  local folder=${fid_prefix}/${fid}/inference_results_from_callback
  local rm_cmd="rm -rf /tmp/$fid{,.tar.gz}" # remove previous copies/downloads if any

  declare -a aws_ssh_opts
  login::maybe_set_login_string
  aws_ssh_opts=(-i "$(login::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

  ssh "${aws_ssh_opts[@]}" "$LOGINSTR" \
    "$rm_cmd && cp -r $folder /tmp/$fid && cd /tmp && tar czf $fid.tar.gz $fid"
  $rm_cmd
  scp "${aws_ssh_opts[@]}" "$LOGINSTR:/tmp/${fid}.tar.gz" /tmp
  cd /tmp/ && tar xf "/tmp/$fid.tar.gz" && xdg-open "$fid"
}

fetch_images "$@"
