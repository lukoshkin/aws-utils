#!/bin/bash

source "$(dirname $0)/login.sh"

forward_port() {
  declare -a aws_ssh_opts
  login::maybe_set_login_string
  aws_ssh_opts=(-i "$(login::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")
  ssh "${aws_ssh_opts[@]}" -NL ${PORT:=6006}:${HOST:-localhost}:$PORT $LOGINSTR
}

forward_port "$@"
