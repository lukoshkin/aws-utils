#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

function help_msg() {
  echo "Usage: $0 [OPTIONS] COMMAND"
  echo "Execute a command on an EC2 instance."
  echo
  echo "Options:"
  echo "  -h, --help                    Show this help message and exit"
  echo "  -A                            Forward SSH agent"
  echo "  -e, --extend-session          Extend the session time"
  echo "  -E=<NUM>, --E=<NUM>           Set the session-time to NUM seconds"
  echo "  -w=<DIR>, --workdir=<DIR>     Change to the specified directory before executing the command"
  echo "  -v                            Verbose mode"
}

function execute_remotely() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return 1
  eval set -- "${_OTHER_ARGS[*]}"

  local long_opts="help,extend-session,workdir:"
  local short_opts="h,e,A,v,E:,w:"
  local params
  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  local workdir extend_session_time=600
  local forward_ssh_agent=false extend_count=0 verbosity=''
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -w | --workdir)
      workdir=$2
      shift
      ;;&
    --E)
      extend_session_time=$2
      shift
      ;;&
    -e | --extend-session) ((extend_count++)) ;;&
    -A) forward_ssh_agent=true ;;&
    -v) verbosity+=v ;;&
    *) shift ;;
    esac
  done

  shift
  [[ -z $1 ]] && {
    echo "Missing the command to execute"
    help_msg
    return 1
  }
  local sshkey ec2_log_file
  ec2_log_file=$(utils::ec2_log_file)
  sshkey=$(utils::get_cfg_entry sshkey)

  if ! [[ ${_AWS_SSH_OPTS[*]} =~ -i[[:space:]=]$sshkey ]]; then
    _AWS_SSH_OPTS+=(-i "$sshkey")
  fi
  if $forward_ssh_agent && ! [[ ${_AWS_SSH_OPTS[*]} =~ -A ]]; then
    _AWS_SSH_OPTS+=(-A)
  fi
  if [[ $extend_count -gt 0 ]]; then
    _AWS_SSH_OPTS+=(-o ClientAliveInterval="$extend_session_time")
    _AWS_SSH_OPTS+=(-o ClientAliveCountMax="$extend_count")
  fi

  utils::maybe_set_login_string
  local exec_cmd=$1
  if [[ $verbosity =~ 'v' ]]; then
    echo "Executing the command: <$exec_cmd>"
    [[ $verbosity =~ 'vv' ]] && echo "SSH options used: ${_AWS_SSH_OPTS[*]}"
    [[ $verbosity =~ 'vvv' ]] && echo "The config file in use: $EC2_CFG_FILE"
  fi
  utils::info '***'
  ssh -A "${_AWS_SSH_OPTS[@]}" "$LOGINSTR" \
    "{ cd $workdir; bash -c '$exec_cmd'; } |& tee -a $ec2_log_file"
  utils::info '***'
}

execute_remotely "$@"
