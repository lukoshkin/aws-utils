#!/bin/bash

source "$(dirname $0)/login.sh"

function strip_quotes() {
  local str=$1
  str=${str//'"'/}
  str=${str//"'"/}
  echo "$str"
}

function process_login_str() {
  local check_in_str=$1
  if [[ -z $check_in_str ]]; then
    check_in_str=$(login::get_cfg_entry logstr)
    [[ -z $check_in_str ]] && {
      >&2 echo Provide 'login_and_host' argument
      return 1
    }
    echo "$check_in_str"
    return 0
  fi

  if [[ $check_in_str = ec2*amazonaws.com ]]; then
    check_in_str="ubuntu@$check_in_str"
  elif [[ $check_in_str != *ec2*amazonaws.com ]]; then
    check_in_str=${check_in_str//./-}
    check_in_str="ubuntu@ec2-$check_in_str.compute-1.amazonaws.com"
  fi
  echo "$check_in_str"
}

function connect() {
  if [[ ! -f $TMP_LOGIN_CFG && -f $HOME_LOGIN_CFG ]]; then
    cp $HOME_LOGIN_CFG $TMP_LOGIN_CFG
  fi

  local login_and_host workdir
  login_and_host="$(process_login_str $1)" || return 1
  entrypoint=$(login::get_cfg_entry entrypoint)
  entrypoint=${entrypoint:-':'}
  entrypoint=$(strip_quotes "$entrypoint")
  workdir=${WORKDIR:-$(login::get_cfg_entry workdir)}
  workdir=${workdir:-'~'}
  workdir=$(strip_quotes "$workdir")

  echo "Connecting to <$login_and_host>"
  echo "Working directory is '$workdir'"
  echo "Entrypoint cmd: '$entrypoint'"
  echo '---'

  timeout ${TIMEOUT:-20} ssh "${AWS_SSH_OPTS[@]}" \
    "$login_and_host" "$entrypoint &>$TMP_LOGIN_LOG" || {
    echo Was not able to start the project containers!
    echo -n "Check the network connection or that you typed"
    echo " in the correct 'login_and_host' string!"
    # Setting `TIMEOUT=` var empty will ignore the command execution status
    [[ -z ${TIMEOUT+any} || -n ${TIMEOUT} ]] && exit 1
  }
  login::set_cfg_entry 'logstr' "$login_and_host"
  login::set_cfg_entry 'workdir' "$workdir"
  ssh -tA "${AWS_SSH_OPTS[@]}" -o ServerAliveInterval=100 "$login_and_host" \
    "cd $workdir &>>$TMP_LOGIN_LOG; exec \$SHELL"
  # -t to set a working directory and run interactive session from it
  # -A to forward your '.ssh' folder
}

connect "$@"
