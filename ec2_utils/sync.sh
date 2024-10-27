#!/bin/bash

source "$(dirname $0)/login.sh"

function help_msg() {
  printf "\nUsage: %s [OPTIONS] SRC [DST]\n" "$0"
  echo "Sync DST folder on the host with the SRC folder on the client"
  echo
  echo "If DST is not provided, it defaults to SRC"
  echo "One can configure defaults using $HOME_LOGIN_CFG"
  echo
  echo "Options:"
  echo "  -h, --help            Show this help message and exit"
  echo "  -e, --execute         The command to execute after sync"
  echo "  -a, --all-files       Ensure all files are synced"
  echo "  -n, --dry-run         Make trial run without making any changes"
}

function sync_remote_with_client() {
  local CUSTOM_ES=21
  local long_opts="execute:,all-files,dry-run,help"
  local short_opts="e:,a,n,h"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return $CUSTOM_ES
  }
  eval set -- "$params"

  local sync_command all_files=false dry_run
  sync_command=$(login::get_cfg_entry sync_command)
  sync_command=${sync_command:-$(
    login::get_cfg_entry sync_cmd "$HOME_LOGIN_CFG"
  )}

  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -e | --execute)
      sync_command=$2
      shift 2
      ;;
    -a | --all-files)
      all_files=true
      shift
      ;;
    -n | --dry-run)
      dry_run='-n'
      shift
      ;;
    *)
      echo Impl.error
      return 1
      ;;
    esac
  done

  shift
  local src=$1
  local dst=${2:-$src}
  [[ -z $src ]] && {
    echo Missing client folder to sync
    return 1
  }
  [[ -d $src ]] || {
    echo "'$src' is either not a folder or the path does not exist"
    return 1
  }

  login::maybe_set_login_string
  declare -a rest_opts_and_args=(
    -avz
    --progress
    --update
    "${src}/"
    "${LOGINSTR}:$dst"
  )
  if [[ -d $src/.git ]] && ! $all_files; then
    rsync "$dry_run" \
      -e "ssh ${AWS_SSH_OPTS[*]}" \
      --files-from=<(git -C "$src" ls-files) \
      "${rest_opts_and_args[@]}"
  else
    rsync "$dry_run" \
      -e "ssh ${AWS_SSH_OPTS[*]}" \
      "${rest_opts_and_args[@]}"
  fi

  if [[ -n $sync_command ]]; then
    if [[ -n $dry_run ]]; then
      echo Executing command..
      echo "<$sync_command>"
      return
    fi
    ssh "${AWS_SSH_OPTS[*]}" "$LOGINSTR" "$sync_command"
  fi
}

sync_remote_with_client "$@"