#!/bin/bash

_ec2_completions() {
  local subcommands="\
connect \
pick \
info \
ls \
execute \
scp-file \
sync \
porforwar \
clean-up \
disconnect \
add \
set-up-user \
init \
home \
install-completions \
"
  COMPREPLY=() # is defined already, we just clear it
  ## Do not try `declare -a` on it ─ will break everything.

  ## Subcommand completion
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$subcommands" -- "$cur")
    return
  fi

  ## Subcommand-specific completion
  local file_mode opts="-h --help -p --pick="
  case "${COMP_WORDS[1]}" in
  scp-file)
    opts+="\
-u --upload \
-t --tar \
-z --gzip \
"
    file_mode=-f
    ;;&

  sync)
    opts+="\
-a --all-files \
-n --dry-run \
-e --execute= \
--client-always-right \
"
    file_mode=-d
    ;;&

  scp-file | sync)
    if [[ ${COMP_WORDS[-1]} = -* ]]; then
      mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
    else
      mapfile -t COMPREPLY < <(compgen "$file_mode" -- "$cur")
    fi
    ;;

  connect)
    opts+="\
-c --cache-opts \
-d --detach \
-e --entrypoint= \
--ip= \
-n --non-interactive \
-s --skip-checks \
-t --revoke-time= \
"
    ;;&

  execute)
    opts+="\
-A \
-e --extend-session \
-E --E= \
-w --workdir= \
-n --no-sep \
-v \
"
    ;;&

  porforwar)
    opts+="\
-s --split \
-H --host= \
-P --port= \
"
    ;;&

  disconnect)
    opts+="\
-a --via-exec \
--no-cleanup \
"
    ;;&

  add) opts="-h --help" ;;&
  info | ls) opts="-h --help -b --non-blocking" ;;&
  connect | execute | porforwar | info | ls | clean-up | disconnect | add | set-up-user)
    mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
    ;;

  install-completions)
    if [[ ${COMP_CWORD} -gt 2 ]]; then
      return
    fi
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    ;;
  esac
}

complete -F _ec2_completions ec2
