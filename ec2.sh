#!/usr/bin/env bash

ec2() {
  local _PARENT_DIR
  _PARENT_DIR="$(readlink -f "$0")"
  _PARENT_DIR="$(dirname "$_PARENT_DIR")/ec2_utils"

  case $1 in
  *)
    shift 1
    ;;&

  home)
    dirname "$_PARENT_DIR"
    ;;
  init)
    bash "$_PARENT_DIR"/init.sh "$@"
    ;;
  pick)
    bash "$_PARENT_DIR"/pick.sh "$@"
    ;;
  ls | info)
    bash "$_PARENT_DIR"/info.sh "$@"
    ;;
  connect)
    bash "$_PARENT_DIR"/connect.sh "$@"
    ;;
  execute)
    bash "$_PARENT_DIR"/execute.sh "$@"
    ;;
  disconnect)
    bash "$_PARENT_DIR"/disconnect.sh "$@"
    ;;
  scp-file)
    bash "$_PARENT_DIR"/scp_file.sh "$@"
    ;;
  sync)
    bash "$_PARENT_DIR"/sync.sh "$@"
    ;;
  porfowar)
    bash "$_PARENT_DIR"/porforwar.sh "$@"
    ;;
  clean-up)
    bash "$_PARENT_DIR"/clean-up.sh "$@"
    ;;
  install-completions)
    [[ $# -gt 1 ]] && {
      echo "Usage: ec2 install-completions [install_path]"
      echo
      echo "Default 'install_path' value:"
      echo 'Zsh: $XDG_CONFIG_HOME/zsh/.zshrc OR ~/.zshrc'
      echo 'Bash: ~/.bashrc'
      return 1
    }

    _PARENT_DIR="$(dirname "$_PARENT_DIR")/completions"
    local completions install_path
    if [[ ${SHELL##*/} == "zsh" ]]; then
      [[ -n $XDG_CONFIG_HOME ]] && {
        ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}
      } || {
        ZDOTDIR=${ZDOTDIR:-~}
      }
      install_path="${ZDOTDIR}/.zshrc"
      completions="$_PARENT_DIR/ec2-compl.zsh"
    elif [[ ${SHELL##*/} == "bash" ]]; then
      completions="$_PARENT_DIR/ec2-compl.bash"
      install_path=${1:-~/.bashrc}
    else
      echo "Unsupported shell"
      return 1
    fi
    if grep -q "ec2-compl" "$install_path"; then
      echo "Completions are already installed."
    else
      echo "source \"$completions\"" >>"$install_path"
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
    printf '  %-25s forward ports from the host to the client\n' 'porfowar'
    printf '  %-25s clean up earlier added inbound rules by ec2\n' 'clean-up'
    printf '  %-25s shutdown the selected instance and run clean-up\n' 'disconnect'
    printf '  %-25s install the shell completions for ec2 command\n' 'install-completions'
    echo
    echo "More about the usage here: https://github.com/lukoshkin/aws-utils/tree/master"
    ;;
  esac
}

ec2 "$@"
