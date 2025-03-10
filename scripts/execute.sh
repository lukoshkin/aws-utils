#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

function help_msg() {
  echo "Usage: ec2 execute [OPTIONS] COMMAND"
  echo "Execute a command on an EC2 instance."
  echo
  echo "Options:"
  echo "  -h, --help                    Show this help message and exit"
  echo "  -A                            Forward SSH agent"
  echo "  -e, --extend-session          Extend the session time"
  echo "  -E=<NUM>, --E=<NUM>           Set the session-time to NUM seconds"
  echo "  -w=<DIR>, --workdir=<DIR>     Change to the specified directory before executing the command"
  echo "  -n, --no-sep                  Do not print the separator before and after the command output"
  echo "  -v                            Verbose mode"
}

function execute::remote_command() {
  declare -a _OTHER_ARGS
  dot::light_pick "$@" || return $?
  eval set -- "${_OTHER_ARGS[*]}"

  local long_opts="help,no-sep,simple,extend-session,workdir:,ssh-opts-string:"
  local short_opts="h,n,s,e,A,v,E:,w:"
  local params
  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 2
  }
  eval set -- "$params"

  local workdir simple=false extend_session_time=100
  local forward_ssh_agent=false extend_count=0 verbosity=''
  local nosep=false
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
    -s | --simple)
      simple=true
      ;;&
    --E)
      extend_session_time=$2
      shift
      ;;&
    --ssh-opts-string)
      read -r -a tmp_array <<<"$2"
      _AWS_SSH_OPTS+=("${tmp_array[@]}")
      shift
      ;;&
    -e | --extend-session) ((extend_count++)) ;;&
    -n | --no-sep) nosep=true ;;&
    -A) forward_ssh_agent=true ;;&
    -v) verbosity+=v ;;&
    *) shift ;;
    esac
  done

  shift
  [[ -z $1 ]] && {
    echo "Missing the command to execute"
    help_msg
    return 2
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
    _AWS_SSH_OPTS+=(-o ServerAliveInterval="$extend_session_time")
    _AWS_SSH_OPTS+=(-o ServerAliveCountMax="$extend_count")
  fi

  ## The check on the empty var is not to duplicate
  ## the log message when using in the other script.
  [[ -z $LOGINSTR ]] && utils::maybe_set_login_string
  [[ $# -gt 2 ]] && {
    echo "Too many arguments"
    help_msg
    return 2
  }

  local exec_cmd_log=$1
  local exec_cmd_no_log=$2
  local exec_cmd
  if $simple; then
    exec_cmd="cd $workdir && $exec_cmd_log"
    [[ $# -gt 1 ]] && {
      utils::error "The second argument is not supported in the simple mode"
      return 2
    }
  else
    exec_cmd="cd $workdir &> $ec2_log_file"
    exec_cmd+="; bash -c '$exec_cmd_log' |& tee -a $ec2_log_file"
    [[ -n $exec_cmd_no_log ]] && exec_cmd+="; $exec_cmd_no_log"
  fi

  case $verbosity in
  vvvv*) utils::warn "Wrong verbosity level" ;;
  v*)
    echo "The command with logging: ▶$exec_cmd_log◀"
    echo "No-log command: ▶$exec_cmd_no_log◀"
    echo "Concatenation of the above : ▶$exec_cmd◀"
    ;;&
  vv*) echo "SSH options used: ${_AWS_SSH_OPTS[*]}" ;;&
  vvv*) echo "The config file in use: $EC2_CFG_FILE" ;;
  esac

  local ec
  $nosep || utils::info "$SEP0"
  ssh -A "${_AWS_SSH_OPTS[@]}" "$LOGINSTR" "$exec_cmd"
  ec=$?
  $nosep || utils::info "$SEP0"
  return $ec
}

## NOTE: might be extended to executing commands across multiple instances
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  execute::remote_command "$@"
fi
