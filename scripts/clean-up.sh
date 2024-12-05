#!/usr/bin/env bash

source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

function clean_up() {
  # shellcheck disable=SC2034
  EC2_CFG_FILE=$(utils::get_cfg_entry cfg_file)

  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)
  login::clean_up "$instance_id"
}

clean_up
