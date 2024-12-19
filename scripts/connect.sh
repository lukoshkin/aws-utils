#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"
source "$SCRIPT_DIR/execute.sh"

_help_msg() {
  echo "Usage: $0 [OPTIONS] [login_and_host]"
  echo "Connect to the specified EC2 instance"
  echo
  echo "Options:"
  echo "  -h, --help                  Show this help message and exit"
  echo "  -e CMD, --entrypoint CMD    Execute the command on the remote machine"
  echo "  -d, --detach                Do not log in on the host"
  echo
  echo "  -p=<NUM>, --pick=<NUM>              Pick the instance to connect to"
  echo "  --ip IP                             Manually specify the IP for the SSH inbound rule to add"
  echo "  -t TIME, --revoke-time TIME         Specify the time in seconds to revoke the added SSH inbound rule"
  echo "  -c, --cache-opts                    Cache the opts passed: workdir, entrypoint (-c), and the picked instance ID (-cc)"
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

  local long_opts="help,skip-checks,cache-opts,detach,workdir:,entrypoint:,ip:,revoke-time:,non-interactive"
  local short_opts="h,s,c,d,w:,e:,t:,n"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  declare -a _ADD_IP4_TO_SG_OPTS
  local detach=false _SKIP_CHECKS=false cache_opts=''
  local workdir entrypoint
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      _help_msg
      return
      ;;
    -s | --skip-checks) _SKIP_CHECKS=true ;;&
    -c | --cache-opts) cache_opts+=c ;;&
    -d | --detach) detach=true ;;&
    -w | --workdir)
      workdir="$2"
      shift
      ;;&
    -e | --entrypoint)
      entrypoint="$2"
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

  case $cache_opts in
  ccc*)
    >&2 echo "Wrong cache-opts value"
    return 2
    ;;
  c*)
    echo 'Caching workdir and entrypoint..'
    [[ -n $workdir ]] && utils::set_cfg_entry workdir "$workdir"
    [[ -n $entrypoint ]] && utils::set_cfg_entry entrypoint "$entrypoint"
    ;;&
  cc*)
    echo 'Caching the picked instance ID..'
    [[ -n $EC2_CFG_FILE ]] && utils::set_cfg_entry cfg_file "$EC2_CFG_FILE"
    ;;
  esac

  login::sanity_checks_and_setup_finalization || return 1
  entrypoint=${entrypoint:-$(utils::get_cfg_entry entrypoint)}
  entrypoint=$(utils::strip_quotes "${entrypoint:-':'}")
  workdir=${workdir:-$(utils::get_cfg_entry workdir)}
  workdir=$(utils::strip_quotes "${workdir:-'~'}")

  echo '---'
  echo "Connecting to <$LOGINSTR>" # defined in login::sanity_checks_and_setup_finalization
  echo -n "The selected instance name: "
  echo -e "$(utils::c "$(cut -d% -f2 <<<"$EC2_CFG_FILE")" 37 1)"
  echo "Working directory is '$workdir'"
  echo "Entrypoint cmd: '$entrypoint'"

  _AWS_SSH_OPTS=(-i "$(utils::get_cfg_entry sshkey)" "${_AWS_SSH_OPTS[@]}")

  ## TODO: currently the logstr key is not set until the session is active
  ## ec2 connect -> Working on the server -> <Ctrl-d>: only now logstr is set
  ## Let's create a small file on the host and download it back. If we managed
  ## to do it, then the connection is 'active'.
  if ! ${_SKIP_CHECKS}; then
    :
  fi

  if ! $detach; then
    execute::remote_command -w "$workdir" \
      --ssh-opts-string='-tA -o ServerAliveInterval=100' \
      "$entrypoint" "exec \$SHELL"
    # -A to forward your '.ssh' folder
    # -t to set a working directory and run interactive session from it
  fi
  _update_connection_status
  echo "Detaching.."
}

connect "$@"
