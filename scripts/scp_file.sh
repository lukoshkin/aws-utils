#!/usr/bin/env bash

source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"
declare -A _CHECKS

function help_msg() {
  echo "Usage: $0 [OPTIONS] SRC [DST]"
  echo "Transfer files and archives between the client and a host."
  echo "To copy from local to host (EC2 instance), use '-u' flag"
  echo "or prefix the whole command with 'UPLOAD=':"
  echo
  echo "UPLOAD= ec2 scp-file file_on_client file_on_host"
  echo
  echo "If DST is not provided, it defaults to SRC"
  echo "One can configure defaults using $HOME_LOGIN_CFG"
  echo
  echo "Options:"
  echo "  -h, --help        Show this help message and exit"
  echo "  -u, --upload      Reverse the file transfer: upload from local to host"
  echo "  -t, --tar         Tar the source folder before copying"
  echo "  -z, --gzip        Gzip the tared folder"
}

function _get_tar_cmd() {
  echo "tar c${2+z}f $1.tar${2+.gz} $1"
}

function get_tar_cmd() {
  [[ -n $2 ]] && {
    _get_tar_cmd "$1" "$2"
    return
  }
  _get_tar_cmd "$1"
}

function get_stem() {
  local target=$1
  target="${1%/}"
  target="${1##*/}"
  [[ $target = '.' ]] || [[ $target = .. ]] && {
    basename "$(realpath "$target")"
    return
  }
  echo "$target"
}

function get_rm_cp_cmd() {
  local target
  target=$(get_stem "$1")
  [[ -z $target ]] && return 1
  echo "rm -rf /tmp/$target{,.tar.gz} && cp -r $1 /tmp/$target"
}

function compose_checks() {
  local host_or_client=${1:-client}
  [[ $host_or_client =~ (client|host) ]] || {
    echo "Invalid 'host_or_client': $host_or_client"
    exit 1
  }

  shift 1
  _CHECKS=()
  if [[ $host_or_client = host ]]; then
    local cmd
    for check in "$@"; do
      cmd+="$check; echo \"$check status=\$?\";"
    done
    while IFS= read -r line; do
      if [[ $line =~ (.*)\ status=([0-9]+) ]]; then
        check="${BASH_REMATCH[1]}"
        status="${BASH_REMATCH[2]}"
        _CHECKS["$check"]="(( ! $status ))"
      fi
    done <<<"$(ssh "${_AWS_SSH_OPTS[@]}" "$LOGINSTR" "$cmd")"
  else
    for check in "$@"; do
      _CHECKS["$check"]="$check"
    done
  fi
}

function check_destination() {
  local dst=$1
  local host_or_client=${2:-client}
  local display_dst=$dst
  if [[ $host_or_client = host ]]; then
    display_dst="$LOGINSTR:$dst"
  fi
  compose_checks "$host_or_client" "[[ -f $dst ]]" "[[ ! -d $(dirname "$dst") ]]" "[[ $dst = /tmp/* ]]"

  if eval "${_CHECKS["[[ -f $dst ]]"]}"; then
    eval "${_CHECKS["[[ $dst = /tmp/* ]]"]}" && {
      local overwrite
      overwrite=$(utils::get_cfg_entry overwrite_in_tmp "$HOME_LOGIN_CFG")
      if [[ $overwrite = true ]]; then
        echo "Overwriting destination file: $display_dst"
        echo "There might be problems because of the existing file permissions"
        return
      fi
    }
    echo "Destination file already exists: $display_dst"
    echo "Please remove it before proceeding"
    return 1
  fi

  if eval "${_CHECKS["[[ ! -d $(dirname "$dst") ]]"]}"; then
    echo "Destination folder for path '$display_dst' does not exist"
    echo "Please create it before proceeding"
    return 1
  fi
}

function scp_file() {
  local long_opts="help,upload,tar,gzip"
  local short_opts="h,u,t,z"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  local gz via_tar
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -u | --upload) UPLOAD=any ;;&
    -t | --tar) via_tar=any ;;&
    -z | --gzip) gz=.gz ;;&
    *) shift ;;
    esac
  done

  shift
  local src=$1
  local dst=${2:-$(
    utils::get_cfg_entry scp_default_dst "$HOME_LOGIN_CFG"
  )}
  local dst=${dst:-$src}
  [[ -z $src ]] && {
    echo Missing source file to copy
    help_msg
    return 1
  }
  # shellcheck disable=SC2034
  EC2_CFG_FILE=$(utils::get_cfg_entry cfg_file)
  utils::maybe_set_login_string

  declare -a _AWS_SSH_OPTS
  _AWS_SSH_OPTS=(-i "$(utils::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

  ## Copying a single file
  [[ -z $via_tar ]] && {
    [[ -n $gz ]] && {
      echo "Ignoring --gzip option since it is only valid with --tar option"
    }
    [[ -z ${UPLOAD+any} ]] && {
      src="$LOGINSTR:$src"
      check_destination "$dst" || return 1
    } || {
      check_destination "$dst" host || return 1
      dst="$LOGINSTR:$dst"
    }
    scp "${_AWS_SSH_OPTS[@]}" "$src" "$dst"
    return
  }

  [[ $src = /tmp/* ]] && {
    echo "Currently I am not able to copy from /tmp folder"
    echo "However, I can copy to /tmp folder!"
    return 1
  }
  if [[ -z ${UPLOAD+any} && ($src = . || $src = ..) ]]; then
    echo "Please specify ¡explicitly! the source folder on the host"
    echo "Using '.' or '..' is not allowed, since it can lead to unexpected results"
    return 1
  fi

  ## Copying a folder
  local target tar_cmd rm_cp_cmd
  target=$(get_stem "$src")
  tar_cmd=$(get_tar_cmd "$target" $gz)
  rm_cp_cmd=$(get_rm_cp_cmd "$src") || {
    echo "Invalid source file"
    return 1
  }
  [[ -z ${UPLOAD+any} ]] && {
    check_destination "$dst" || return 1
    src="$LOGINSTR:/tmp/$target.tar${gz}"
    ssh "${_AWS_SSH_OPTS[@]}" "$LOGINSTR" "$rm_cp_cmd && cd /tmp && $tar_cmd"
  } || {
    check_destination "$dst" host || return 1
    eval "$rm_cp_cmd && cd /tmp && $tar_cmd"
    src="/tmp/$target.tar${gz}"
    dst="$LOGINSTR:$dst"
  }
  scp "${_AWS_SSH_OPTS[@]}" "$src" "$dst"
}

scp_file "$@"
