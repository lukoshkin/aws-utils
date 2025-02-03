#!/bin/bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/pick.sh"

function help_msg() {
  echo "Usage: ec2 info [-h|--help|-b|--non-blocking]"
  echo "Show the information about the available instances."
}

function info() {
  [[ $# -gt 1 ]] && {
    help_msg
    return 2
  }
  [[ $# -eq 0 ]] && {
    pk::peek
    return $?
  }
  if [[ $1 == '-h' || $1 == '--help' ]]; then
    help_msg
    return 0
  elif [[ $1 == '-b' || $1 == '--non-blocking' ]]; then
    (
      local flag=true
      while read -r line; do
        $flag && {
          echo
          echo "$line"
          echo -n "(${SHELL##*/}) > "
          # ${SHELL##*/} --login -ic 'echo -en "\n$PS1"'
          flag=false
          continue
        }
        echo "$line"
      done < <(pk::peek)
      # ${SHELL##*/} --login -ic 'echo -en "\n$PS1"'
      echo -n "(${SHELL##*/}) > "
    ) &
  else
    help_msg
    return 2
  fi
}

info "$@"
