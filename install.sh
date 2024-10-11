#!/usr/bin/env bash

link_ec2() {
  sudo ln -sf "$(readlink -f ec2.sh)" /usr/local/bin/ec2
}

[[ -f ec2.sh ]] && {
  INSTALL_PATH=$PWD
}

echo "Using ${INSTALL_PATH:='~/.config/aws-utils'} as install path"
if [[ -d ${INSTALL_PATH} ]]; then
  cd "$INSTALL_PATH" && {
    git pull
    link_ec2
  }
else
  git clone https://github.com/lukoshkin/aws-utils.git "$INSTALL_PATH"
  cd "$INSTALL_PATH" && link_ec2
fi
