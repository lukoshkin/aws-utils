#!/usr/bin/env bash

ec2() {
  local _PARENT_DIR
  _PARENT_DIR="$(readlink -f "$0")"
  _PARENT_DIR="$(dirname "$_PARENT_DIR")/ec2_utils"

  case $1 in
  *)
    shift 1
    ;;&
  connect)
    bash "$_PARENT_DIR"/connect.sh "$@"
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
    echo "Usage: ec2 {connect|scp-file|porfowar|disconnect|install-completions} [args]"
    echo "More about the usage here: https://github.com/lukoshkin/aws-utils/tree/master"
    ;;
  esac
}

ec2 "$@"
