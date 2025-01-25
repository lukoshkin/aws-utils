#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

_help_msg() {
  echo "Usage: ec2 connect [OPTIONS] [login_and_host]"
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
  echo "  -c, --cache-opts                    Cache the opts passed: workdir, entrypoint, user (-c), and the picked instance ID (-cc)"
  echo "  -n, --non-interactive               A security group auto-select (may be extended later)"
}

_update_connection_status() {
  if [[ $? -eq 0 ]]; then
    IFS=@ read -r _ host <<<"$LOGINSTR"
    utils::set_cfg_entry connection active
    utils::set_cfg_entry host "$host"
  else
    utils::set_cfg_entry connection broken
    utils::set_cfg_entry host
  fi
}

function connect() {
  local long_opts="help,skip-checks,cache-opts,detach,user:,workdir:,entrypoint:,ip:,revoke-time:,non-interactive"
  local short_opts="h,s,c,d,u:,w:,e:,t:,n"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 2
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
    -u | --user)
      EC2_USER="$2"
      shift
      ;;&
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
    utils::error "'connect' does not accept any positional arguments"
    return 2
  }

  case $cache_opts in
  ccc*)
    utils::error "Wrong cache-opts value"
    return 2
    ;;
  c*)
    echo 'Caching workdir, entrypoint, and user..'
    [[ -n $workdir ]] && utils::set_cfg_entry workdir "$workdir"
    [[ -n $EC2_USER ]] && utils::set_cfg_entry user "$EC2_USER"
    [[ -n $entrypoint ]] && utils::set_cfg_entry entrypoint "$entrypoint"
    ;;&
  cc*)
    echo 'Caching the picked instance ID..'
    [[ -n $EC2_CFG_FILE ]] && {
      local bak_cfg_file=$EC2_CFG_FILE
      unset EC2_CFG_FILE  # in order to write to EC2_CFG_MAIN

      utils::set_cfg_entry cfg_file "$bak_cfg_file"
      EC2_CFG_FILE=$bak_cfg_file
    }
    ;;
  esac

  login::sanity_checks_and_setup_finalization || return $?
  entrypoint=${entrypoint:-$(utils::get_cfg_entry entrypoint)}
  entrypoint=$(utils::strip_quotes "${entrypoint:-':'}")
  workdir=${workdir:-$(utils::get_cfg_entry workdir)}
  workdir=$(utils::strip_quotes "${workdir:-'~'}")

  echo "$SEP1"
  echo "Connecting to <$LOGINSTR>" # defined in login::sanity_checks_and_setup_finalization
  echo -n "The selected instance name: "
  echo -e "$(utils::c "$(cut -d% -f2 <<<"$EC2_CFG_FILE")" 37 1)"
  echo "Working directory is '$workdir'"
  echo "Entrypoint cmd: '$entrypoint'"

  export EC2_CFG_FILE EC2_USER LOGINSTR
  _AWS_SSH_OPTS=(-i "$(utils::get_cfg_entry sshkey)" "${_AWS_SSH_OPTS[@]}")

  if ! ${_SKIP_CHECKS}; then
    local _ending
    _ending=$(timeout 5 bash "$SCRIPT_DIR"/execute.sh "echo" | tail -1)
    _ending=$(sed -E 's/\x1B\[[0-9;]*m//g' <<<"$_ending")
    [[ $_ending = "$SEP0" ]] && _update_connection_status
  fi

  if ! $detach; then
    # -t to set a working directory and run interactive session from it
    # -A to forward your '.ssh' folder on the remote machine
    bash "$SCRIPT_DIR"/execute.sh -w "$workdir" \
      --ssh-opts-string='-tA -o ServerAliveInterval=100' \
      "$entrypoint" "exec \$SHELL"
  fi
  _update_connection_status
  echo "Detaching.."
}

function check_option_d() {
  if [[ ${#_SPLIT_TARGET_OPTIONS[@]} -gt 2 ]] &&
    ! [[ $* =~ (^|[[:space:]])-[a-zA-Z]*d.* ]]; then
    utils::error "Cannot connect to multiple instances at once."
    utils::info "One can use '-d' in combination with '-p' to start multiple instances."
    return 2
  fi
}

dot::manage_multiple_instances connect check_option_d -- "$@"
