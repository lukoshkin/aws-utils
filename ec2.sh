#!/usr/bin/env bash

ec2() {
  local _PARENT_DIR
  _PARENT_DIR="$(readlink -f "$0")"
  _PARENT_DIR="$(dirname "$_PARENT_DIR")/ec2_utils"

  case $1 in
  *)
    shift 1
    ;;&
  connect)
    bash "$_PARENT_DIR"/connect.sh "$@"
    ;;
  scp-file)
    bash "$_PARENT_DIR"/scp_file.sh "$@"
    ;;
  porfowar)
    bash "$_PARENT_DIR"/porforwar.sh "$@"
    ;;
  *)
    echo "Usage: ec2 {connect|scp-file|porfowar} [args]"
    echo "More about the usage here: https://github.com/lukoshkin/aws-utils/tree/master"
    ;;
  esac
}

ec2 "$@"
