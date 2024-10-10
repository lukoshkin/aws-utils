#!/bin/bash

source "$(dirname $0)/login.sh"

forward_port() {
  login::maybe_set_login_string
  ssh "${AWS_SSH_OPTS[@]}" -NL ${PORT:=6006}:${HOST:-localhost}:$PORT $LOGINSTR
}

forward_port "$@"
