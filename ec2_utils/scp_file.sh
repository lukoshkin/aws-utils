#!/bin/bash

source "$(dirname $0)/login.sh"

function help_msg() {
  printf "Usage: %s [OPTIONS] SRC [DST]\n" "$0"
  echo "Copy file from SRC to DST."
  echo "If DST is not provided, it defaults to SRC"
  echo
  echo "Options:"
  echo "  -h, --help        Show this help message and exit"
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
  echo "$target"
}

function get_rm_cp_cmd() {
  local target
  target=$(get_stem "$1")
  [[ -z $target ]] && {
    echo "Invalid source file"
    exit 1
  }
  echo "rm -rf /tmp/$target{,.tar.gz} && cp -r $1 /tmp/$target"
}

function scp_file() {
  login::maybe_set_login_string
  CUSTOM_ES=21

  local long_opts="tar,gzip,help"
  local short_opts="t,z,h"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return $CUSTOM_ES
  }
  eval set -- "$params"

  local gz via_tar
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -t | --tar)
      via_tar=any
      shift 1
      ;;
    -z | --gzip)
      gz=.gz
      shift 1
      ;;

    *)
      echo Impl.error
      return 1
      ;;
    esac
  done

  shift 1
  local src=$1
  local dst=${2:-$src}
  [[ -z $src ]] && {
    echo Missing source file to copy
    help_msg
    exit 1
  }
  [[ -z $via_tar ]] && {
    [[ -n $gz ]] && {
      echo "Ignoring --gzip option since it is only valid with --tar option"
    }
    [[ -z ${UPLOAD+any} ]] && src="$LOGINSTR:$src" || dst="$LOGINSTR:$dst"
    scp "${AWS_SSH_OPTS[@]}" "$src" "$dst"
    return
  }

  [[ $src = /tmp/* ]] && {
    echo "Currently I am not able to copy from /tmp folder"
    echo "However, I can copy to /tmp folder!"
    exit 1
  }

  local target tar_cmd rm_cp_cmd
  target=$(get_stem "$src")
  tar_cmd=$(get_tar_cmd "$target" $gz)
  rm_cp_cmd=$(get_rm_cp_cmd "$src")
  [[ -z ${UPLOAD+any} ]] && {
    src="$LOGINSTR:/tmp/$target.tar${gz}"
    ssh "${AWS_SSH_OPTS[@]}" "$LOGINSTR" "$rm_cp_cmd && cd /tmp && $tar_cmd"
  } || {
    eval "$rm_cp_cmd && cd /tmp && $tar_cmd"
    src="/tmp/$target.tar${gz}"
    dst="$LOGINSTR:$dst"
  }
  scp "${AWS_SSH_OPTS[@]}" "$src" "$dst"
}

scp_file "$@"
