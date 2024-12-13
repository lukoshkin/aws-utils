#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"
source "$SCRIPT_DIR/execute.sh"

_help_msg() {
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
  echo "  -p=<NUM>, --pick=<NUM>              Pick the instance to connect to"
  echo "  -n, --non-interactive               A security group auto-select (may be extended later)"
}

_update_connection_status() {
  if [[ $? -eq 0 ]]; then
    utils::set_cfg_entry connection active
    utils::set_cfg_entry logstr "$LOGINSTR"
  else
    utils::set_cfg_entry connection broken
    utils::set_cfg_entry logstr
  fi
}

function connect() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return 1
  eval set -- "${_OTHER_ARGS[*]}"

  local long_opts="non-interactive,skip-checks,execute:,detach,ip:,revoke-time:,help"
  local short_opts="n,s,e:,d,t:,h"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  declare -a _ADD_IP4_TO_SG_OPTS
  local exec_cmd detach=false _SKIP_CHECKS=false
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      _help_msg
      return
      ;;
    -s | --skip-checks) _SKIP_CHECKS=true ;;&
    -d | --detach) detach=true ;;&
    -e | --execute)
      ## TODO: make a separate subcommand for it. Pass option to make more
      ## stable server-client connections with 'ClientAliveInterval' and
      ## 'ClientAliveCountMax'.
      detach=true
      exec_cmd="$2"
      shift
      ;;&
    -t | --ip | --revoke-time)
      _ADD_IP4_TO_SG_OPTS+=("$1" "$2")
      shift
      ;;&
    -n | --non-interactive)
      _ADD_IP4_TO_SG_OPTS+=("$1")
      ;;&
    *) shift ;;
    esac
  done

  shift
  [[ -n $1 ]] && {
    >&2 echo "'connect' does not accept any positional arguments"
    return 1
  }
  login::sanity_checks_and_setup_finalization || return 1
  entrypoint=$(utils::get_cfg_entry entrypoint)
  entrypoint=$(utils::strip_quotes "${entrypoint:-':'}")
  workdir=${WORKDIR:-$(utils::get_cfg_entry workdir)}
  workdir=$(utils::strip_quotes "${workdir:-'~'}")

  echo '---'
  echo "Connecting to <$LOGINSTR>" # defined in login::sanity_checks_and_setup_finalization
  echo -n "The selected instance name: "
  echo -e "$(utils::c "$(cut -d% -f2 <<<"$EC2_CFG_FILE")" 37 1)"
  echo "Working directory is '$workdir'"
  echo "Entrypoint cmd: '$entrypoint'"
  echo '---'

  local ec2_log_file
  ec2_log_file=$(utils::ec2_log_file)
  _AWS_SSH_OPTS=(-i "$(utils::get_cfg_entry sshkey)" "${_AWS_SSH_OPTS[@]}")

  ## TODO: currently the logstr key is not set until the session is active
  ## ec2 connect -> Working on the server -> <Ctrl-d>: only now logstr is set
  ## Let's create a small file on the host and download it back. If we managed
  ## to do it, then the connection is 'active'.

  if [[ -n $entrypoint && $entrypoint != ':' ]]; then
    timeout "${TIMEOUT:-20}" ssh "${_AWS_SSH_OPTS[@]}" \
      "$LOGINSTR" "$entrypoint &>>$ec2_log_file" || {
      echo "(DEBUG: the return status is <$?>)"
      echo Was not able to execute the entrypoint command!
      echo -n "Check the network connection or that you typed"
      echo " in the correct 'login_and_host' string!"
      utils::set_cfg_entry connection broken

      ## Setting `TIMEOUT=` var empty will ignore
      ## the execution status of the command above
      [[ -z ${TIMEOUT+any} || -n ${TIMEOUT} ]] && exit 1
    }
    _update_connection_status
  fi
  if ! $detach; then
    # -A to forward your '.ssh' folder
    # -t to set a working directory and run interactive session from it
    execute::remote_command \
      --ssh-opts-string='-tA -o ServerAliveInterval=100' \
      "$entrypoint" "exec \$SHELL"
  elif [[ -n $exec_cmd ]]; then # when provided '-e', detach is always false
    execute_remotely "$exec_cmd"
    _update_connection_status
  fi
  echo "Detaching.."
}

connect "$@"
