#!/bin/bash

HOME_LOGIN_CFG=~/.ec2_login_opts
TMP_LOGIN_CFG=/tmp/ec2_last_login_opts
TMP_LOGIN_LOG=/tmp/ec2_last_login.log

login::get_cfg_entry() {
  local key=$1
  [[ -f ${2:-$TMP_LOGIN_CFG} ]] || return
  sed -r "s;$key: (.*);\1;" <<<"$(grep "^$key:" ${2:-$TMP_LOGIN_CFG})"
}

login::set_cfg_entry() {
  local key=$1
  local value=$2
  if [[ -f $TMP_LOGIN_CFG ]] && grep -q "^$key:" $TMP_LOGIN_CFG; then
    sed -ri "s;^$key: .*;$key: $value;" $TMP_LOGIN_CFG
  else
    echo "$key: $value" >>$TMP_LOGIN_CFG
  fi
}

login::maybe_set_login_string() {
  msg="Using ${LOGINSTR:=$(login::get_cfg_entry logstr)} as login string"
  [[ -z $LOGINSTR ]] && {
    echo "No login string found"
    exit 1
  }
  echo $msg
}


AWS_SSH_KEY=$(login::get_cfg_entry sshkey $HOME_LOGIN_CFG)
AWS_SSH_KEY=${AWS_SSH_KEY:-'~/.ssh/convai-qoreai.pem'}
# -i <...>.pem ─ login key pair (created during EC2 instance launch on AWS)
# -o UserKnownHostsFile=/dev/null ─ do not pollute known_hosts with a varying IP
# -o StrictHostKeychecking=no ─ skip the question about adding a new fingerprint
# -o IdentitiesOnly ─ ignore your '.ssh/config'
declare -a AWS_SSH_OPTS=(
  "-i"
  "$AWS_SSH_KEY"
  "-o"
  "IdentitiesOnly=yes"
  "-o"
  "UserKnownHostsFile=/dev/null"
  "-o"
  "StrictHostKeychecking=no"
)
