#!/usr/bin/env bash

link_ec2() {
  sudo ln -sf "$(readlink -f ec2.sh)" /usr/local/bin/ec2
}

[[ -f ec2.sh ]] && INSTALL_PATH=$PWD
_DEFAULT_INSTALL_PATH=${XDG_CONFIG_HOME:-$HOME/.config}/aws-utils
echo "Using ${INSTALL_PATH:=${_DEFAULT_INSTALL_PATH}} as install path"

if [[ -d ${INSTALL_PATH} ]]; then
  cd "$INSTALL_PATH" && {
    git pull
    link_ec2
  }
else
  git clone https://github.com/lukoshkin/aws-utils.git "$INSTALL_PATH"
  cd "$INSTALL_PATH" && link_ec2
fi
