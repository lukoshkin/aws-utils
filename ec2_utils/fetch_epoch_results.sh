#!/bin/bash

source "$(dirname $0)/login.sh"

function fetch_images() {
  local fid=$1
  local fid_prefix=/home/$EC2_USER/assets/${TASK:-detector}/single_run
  local folder=${fid_prefix}/${fid}/inference_results_from_callback
  local rm_cmd="rm -rf /tmp/$fid{,.tar.gz}" # remove previous copies/downloads if any

  login::maybe_set_login_string
  ssh "${AWS_SSH_OPTS[@]}" "$LOGINSTR" \
    "$rm_cmd && cp -r $folder /tmp/$fid && cd /tmp && tar czf $fid.tar.gz $fid"
  $rm_cmd
  scp "${AWS_SSH_OPTS[@]}" "$LOGINSTR:/tmp/${fid}.tar.gz" /tmp
  cd /tmp/ && tar xf /tmp/$fid.tar.gz && xdg-open $fid
}

fetch_images "$@"
