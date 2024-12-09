#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

function help_msg() {
  echo "Usage: $0 [OPTIONS]"
  echo "Disconnect from an EC2 instance."
  echo
  echo "Options:"
  echo "  -h, --help                Show this help message and exit"
  echo "  -a, --via-exec            Disconnect via executing 'sudo shutdown -h now' on the instance"
  echo "  -p=<NUM>, --pick=<NUM>    Pick an instance to disconnect from"
  echo "  --no-cleanup              Skip the cleanup step"
}

function disconnect() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return 1
  eval set -- "${_OTHER_ARGS[*]}"

  local long_opts="help,no-cleanup,via-exec"
  local short_opts="h,a"
  local params
  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  local no_cleanup=false via_exec=false
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -a | --via-exec) via_exec=true ;;&
    --no-cleanup) no_cleanup=true ;;&
    *) shift ;;
    esac
  done

  shift
  [[ -n $1 ]] && {
    echo "Unknown argument: $1"
    help_msg
    return 1
  }

  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)

  if $via_exec; then
    declare -a aws_ssh_opts
    aws_ssh_opts=(-i "$(utils::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

    utils::maybe_set_login_string
    ssh "${aws_ssh_opts[@]}" "$LOGINSTR" "sudo shutdown -h now"
  else
    aws ec2 stop-instances --instance-ids "$instance_id"
  fi

  if ! $no_cleanup; then
    login::clean_up "$instance_id"
  fi
}

disconnect "$@"
