#!/usr/bin/env bash

source "$(dirname $0)/aws-login.sh"

function help_msg() {
  printf "\nUsage: %s [OPTIONS] SRC [DST]\n" "$0"
  echo "Sync DST folder on the host with the SRC folder on the client"
  echo
  echo "If DST is not provided, it defaults to SRC"
  echo "One can configure defaults using $HOME_LOGIN_CFG"
  echo
  echo "Options:"
  echo "  -h, --help                   Show this help message and exit"
  echo "  -e CMD, --execute CMD        The command to execute after sync"
  echo "  -a, --all-files              Ensure all files are synced"
  echo "  -n, --dry-run                Make trial run without making any changes"
  echo "  --client-always-right        Update with client files even if their modify-times are older"
}

function sync_remote_with_client() {
  local long_opts="execute:,all-files,client-always-right,dry-run,help"
  local short_opts="e:,a,n,h"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return "$CUSTOM_ES"
  }
  eval set -- "$params"

  local sync_command all_files=false no_update=false dry_run=-v
  sync_command=$(utils::get_cfg_entry sync_command)
  sync_command=${sync_command:-$(
    utils::get_cfg_entry sync_command "$HOME_LOGIN_CFG"
  )}

  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -e | --execute)
      sync_command=${2#=}
      shift 2
      ;;
    -a | --all-files)
      all_files=true
      shift
      ;;
    --client-always-right)
      no_update=true
      shift
      ;;
    -n | --dry-run)
      dry_run=-nv
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

  utils::maybe_set_login_string
  declare -a rest_opts_and_args=(
    -az
    --progress
    --update
    "${src%/}"
    "${LOGINSTR}:$dst"
  )
  $no_update && unset 'rest_opts_and_args[2]'

  declare -a aws_ssh_opts
  aws_ssh_opts=(-i "$(utils::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

  ## Since we run without `eval`, `dry_run` can't be empty.
  ## Or will be treated as an empty argument otherwise
  if [[ -d $src/.git ]] && ! $all_files; then
    rsync "$dry_run" \
      -e "ssh ${aws_ssh_opts[*]}" \
      --files-from=<(git -C "$src" ls-files) \
      "${rest_opts_and_args[@]}"
  else
    rsync "$dry_run" \
      -e "ssh ${aws_ssh_opts[*]}" \
      "${rest_opts_and_args[@]}"
  fi

  if [[ -n $sync_command ]]; then
    if [[ $dry_run =~ 'n' ]]; then
      echo Executing command..
      echo "<$sync_command>"
      return
    fi
    ssh "${aws_ssh_opts[@]}" "$LOGINSTR" "cd $dst && $sync_command"
  fi
}

sync_remote_with_client "$@"
