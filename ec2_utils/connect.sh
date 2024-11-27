#!/usr/bin/env bash

source "$(dirname "$0")/aws-login.sh"
source "$(dirname "$0")/utils.sh"

function help_msg() {
  echo "Usage: $0 [OPTIONS] [login_and_host]"
  echo "Connect to the specified EC2 instance"
  echo
  echo "Options:"
  echo "  -h, --help               Show this help message and exit"
  echo "  -e CMD, --execute CMD    Execute the command on the remote machine"
  echo "  -d, --detach             Do not log in on the host"
  echo
  echo '  [beta]'
  echo "  --ip IP                             Manually specify the IP for the SSH inbound rule to add"
  echo "  -t TIME, --revoke-time TIME         Specify the time in seconds to revoke the added SSH inbound rule"
  echo "  -p=[NUM], --pick-instance=[NUM]     Pick the instance to connect to"
  echo "  -n, --non-interactive               A security group auto-select (may be extended later)"
}

function connect() {
  local long_opts="non-interactive,pick-instance:,execute:,detach,ip:,revoke-time:,help"
  local short_opts="n,p:,e:,d,t:,h"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  ## Check if TMP_LOGIN_CFG exists BEFORE any calls of `utils::set_cfg_entry`.
  ## Calling `utils::set_cfg_entry` before this check will create the file,
  ## and thus, will break the initialization with a good seed.
  if [[ ! -f $TMP_LOGIN_CFG && -f $HOME_LOGIN_CFG ]]; then
    cp "$HOME_LOGIN_CFG" "$TMP_LOGIN_CFG"
  fi

  declare -a _ADD_IP4_TO_SG_OPTS
  local exec_cmd detach=false clear_logstr=false
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -p | -t | --ip | --pick-instance | --revoke-time)
      clear_logstr=true
      ;;&
    -p | --pick-instance)
      bash "$(dirname "$0")/pick.sh" "$2" || return 1
      shift 2
      ;;
    -d | --detach)
      detach=true
      shift
      ;;
    -e | --execute)
      ## TODO: make a separate subcommand for it. Pass option to make more
      ## stable server-client connections with 'ClientAliveInterval' and
      ## 'ClientAliveCountMax'.
      detach=true
      exec_cmd="$2"
      shift 2
      ;;
    -t | --ip | --revoke-time)
      _ADD_IP4_TO_SG_OPTS+=("$1" "$2")
      shift 2
      ;;
    -n | --non-interactive)
      _ADD_IP4_TO_SG_OPTS+=("$1")
      shift
      ;;
    *)
      echo Impl.error
      return 1
      ;;
    esac
  done

  shift

  if $clear_logstr; then
    utils::set_cfg_entry 'logstr'
  fi

  local _LOGINSTR
  login::sanity_checks "$1" || return 1

  entrypoint=$(utils::get_cfg_entry entrypoint)
  entrypoint=$(utils::strip_quotes "${entrypoint:-':'}")
  workdir=${WORKDIR:-$(utils::get_cfg_entry workdir)}
  workdir=$(utils::strip_quotes "${workdir:-'~'}")

  echo "Connecting to <$_LOGINSTR>"
  echo "Working directory is '$workdir'"
  echo "Entrypoint cmd: '$entrypoint'"
  echo '---'

  declare -a aws_ssh_opts
  aws_ssh_opts=(-i "$(utils::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

  if [[ -n $entrypoint && $entrypoint != ':' ]]; then
    timeout "${TIMEOUT:-20}" ssh "${aws_ssh_opts[@]}" \
      "$_LOGINSTR" "$entrypoint &>>$TMP_LOGIN_LOG" || {
      echo Was not able to start the project containers!
      echo -n "Check the network connection or that you typed"
      echo " in the correct 'login_and_host' string!"
      # Setting `TIMEOUT=` var empty will ignore the command execution status
      [[ -z ${TIMEOUT+any} || -n ${TIMEOUT} ]] && exit 1
    }
  fi
  utils::set_cfg_entry 'logstr' "$_LOGINSTR"
  utils::set_cfg_entry 'workdir' "$workdir"
  if ! $detach; then
    ssh -tA "${aws_ssh_opts[@]}" -o ServerAliveInterval=100 "$_LOGINSTR" \
      "cd $workdir &>>$TMP_LOGIN_LOG; exec \$SHELL"
    # -t to set a working directory and run interactive session from it
    # -A to forward your '.ssh' folder
    return
  fi
  if [[ -n $exec_cmd ]]; then
    echo "Executing command: <$exec_cmd>"
    ssh -A "${aws_ssh_opts[@]}" "$_LOGINSTR" \
      "{ cd $workdir; bash -c '$exec_cmd'; } |& tee -a $TMP_LOGIN_LOG"
  fi
  echo -e "\nDetaching.."
}

connect "$@"
