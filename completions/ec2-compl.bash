#!/bin/bash

_ec2_completions() {
  local subcommands
  subcommands="connect scp-file sync porfowar disconnect install-completions"
  COMPREPLY=() # is defined already, we just clear it
  ## Do not try `declare -a` on it ─ will break everything.

  ## Subcommand completion
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$subcommands" -- "${COMP_WORDS[-1]}")
    return
  fi

  ## Subcommand-specific completion
  local opts file_mode
  case "${COMP_WORDS[1]}" in
  scp-file)
    opts="-t --tar -z --gzip"
    file_mode=-f
    ;;&

  sync)
    opts="-a --all-files -n --dry-run -e --execute= --client-always-right"
    file_mode=-d
    ;;&

  scp-file | sync)
    if [[ ${COMP_WORDS[-1]} = -* ]]; then
      mapfile -t COMPREPLY < <(compgen -W "$opts" -- "${COMP_WORDS[-1]}")
    else
      mapfile -t COMPREPLY < <(compgen "$file_mode" -- "${COMP_WORDS[-1]}")
    fi
    ;;&

  install-completions)
    if [[ ${COMP_CWORD} -gt 2 ]]; then
      return
    fi
    mapfile -t COMPREPLY < <(compgen -f -- "${COMP_WORDS[-1]}")
    ;;&

  *)
    return
    ;;
  esac
}

complete -F _ec2_completions ec2
