#!/usr/bin/env bash

ec2() {
  local root scripts completions
  root=$(dirname "$(readlink -f "$0")")
  completions="$root/completions"
  scripts="$root/scripts"

  case $1 in
  *)
    shift 1
    ;;&

  home)
    echo "$root"
    ;;
  init)
    bash "$scripts"/init.sh "$@"
    ;;
  pick)
    bash "$scripts"/pick.sh "$@"
    ;;
  add)
    bash "$scripts"/add.sh "$@" # TODO: test more
    ;;
  ls | info)
    bash "$scripts"/info.sh "$@"
    ;;
  connect)
    bash "$scripts"/connect.sh "$@"
    ;;
  execute)
    bash "$scripts"/execute.sh "$@"
    ;;
  disconnect)
    bash "$scripts"/disconnect.sh "$@"
    ;;
  scp-file)
    bash "$scripts"/scp_file.sh "$@"
    ;;
  sync)
    bash "$scripts"/sync.sh "$@"
    ;;
  porforwar)
    bash "$scripts"/porforwar.sh "$@"
    ;;
  clean-up)
    bash "$scripts"/clean-up.sh "$@"
    ;;
  install-completions)
    [[ $# -gt 1 ]] && {
      echo "Usage: ec2 install-completions [install_path]"
      echo
      echo "Default 'install_path' value:"
      echo " - Zsh: \$XDG_CONFIG_HOME/zsh/.zshrc OR ~/.zshrc"
      echo ' - Bash: ~/.bashrc'
      return 1
    }

    local compl_path install_path
    if [[ ${SHELL##*/} == "zsh" ]]; then
      [[ -n $XDG_CONFIG_HOME ]] && {
        ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}
      } || {
        ZDOTDIR=${ZDOTDIR:-~}
      }
      install_path="${ZDOTDIR}/.zshrc"
      compl_path="$completions/ec2-compl.zsh"
    elif [[ ${SHELL##*/} == "bash" ]]; then
      compl_path="$completions/ec2-compl.bash"
      install_path=${1:-~/.bashrc}
    else
      echo "Unsupported shell"
      return 1
    fi
    if grep -q "ec2-compl" "$install_path"; then
      echo "Completions are already installed."
    else
      echo "source \"$compl_path\"" >>"$install_path"
      echo "Installed completions to $install_path!"
    fi
    ;;
  *)
    echo "Usage: ec2 SUBCMD [args]"
    echo "Available sub-commands:"
    echo
    printf '  %-25s show the installation folder of ec2\n' 'home'
    printf '  %-25s create ec2_login_opts folder\n' 'init'
    printf '  %-25s pick an EC2 instance to continue with\n' 'pick'
    printf '  %-25s display information about EC2 instances\n' 'ls|info'
    printf '  %-25s connect to the selected instance\n' 'connect'
    printf '  %-25s execute command on the host without interactive login\n' 'execute'
    printf '  %-25s transfer file or archive between the client and host\n' 'scp-file'
    printf '  %-25s forward ports from the host to the client\n' 'porforwar'
    printf '  %-25s clean up earlier added inbound rules by ec2\n' 'clean-up'
    printf '  %-25s shutdown the selected instance and run clean-up\n' 'disconnect'
    printf '  %-25s install the shell completions for ec2 command\n' 'install-completions'
    echo
    echo "More about the usage here: https://github.com/lukoshkin/aws-utils/tree/master"
    ;;
  esac
}

ec2 "$@"
