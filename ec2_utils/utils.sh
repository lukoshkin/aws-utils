#!/bin/bash

CUSTOM_ES=21 # custom exit status
HOME_LOGIN_CFG=${EC2_LOGIN_CFG_PATH:-~/.ec2_login_opts}
## TODO: create a tmp config per each instance
TMP_LOGIN_CFG=/tmp/ec2_$USER-last_login_opts

utils::get_cfg_entry() {
  local key=${1%:}
  local key=${key%:-}
  [[ -f ${2:-$TMP_LOGIN_CFG} ]] || return
  grep -q "^$key:-" "${2:-$TMP_LOGIN_CFG}" && {
    sed -n "/^$key:-/,/^$/p" "${2:-$TMP_LOGIN_CFG}" | sed -n '1!p'
    return
  }
  sed -r "s;$key: (.*);\1;" <<<"$(grep "^$key:" "${2:-$TMP_LOGIN_CFG}")"
}

utils::set_cfg_entry() {
  local key=${1%:}
  local value=$2
  if [[ -f $TMP_LOGIN_CFG ]] && grep -q "^${key%:-}:" "$TMP_LOGIN_CFG"; then
    [[ $# -eq 1 ]] && {
      if [[ $key = *:- ]]; then
        sed -ri "/^$key/,/^$/d" "$TMP_LOGIN_CFG"
      else
        sed -ri "/^$key:\(?!-\)/d" "$TMP_LOGIN_CFG"
      fi
      return
    }
    if [[ $key = *:- ]]; then
      sed -ri "/^$key/,/^$/ { /^$/ {s/^/$value\n/; } }" "$TMP_LOGIN_CFG"
    else
      sed -ri "s;^$key: .*;$key: $value;" "$TMP_LOGIN_CFG"
    fi
  else
    [[ $# -eq 1 ]] && return
    if [[ $key = *:- ]]; then
      echo "$key" >>"$TMP_LOGIN_CFG"
      echo -e "$value\n" >>"$TMP_LOGIN_CFG"
    else
      echo "$key: $value" >>"$TMP_LOGIN_CFG"
    fi
  fi
}

EC2_USER=$(utils::get_cfg_entry user "$HOME_LOGIN_CFG")
EC2_USER=${EC2_USER:-'ubuntu'}
TMP_LOGIN_LOG=/tmp/ec2_${USER}-${EC2_USER}-last_login.log
declare -a AWS_SSH_OPTS=(
  '-o'
  'IdentitiesOnly=yes'
  '-o'
  'UserKnownHostsFile=/dev/null'
  '-o'
  'StrictHostKeyChecking=no'
  '-o'
  'LogLevel=Error'
)
# -i <...>.pem ─ login key pair (created during EC2 instance launch on AWS)
# -o UserKnownHostsFile=/dev/null ─ do not pollute known_hosts with a varying IP
# -o StrictHostKeychecking=no ─ skip the question about adding a new fingerprint
# -o IdentitiesOnly ─ ignore your '.ssh/config'

utils::strip_quotes() {
  local str=$1
  str=${str//'"'/}
  str=${str//"'"/}
  echo "$str"
}

utils::select_option() {
  select option in "$@"; do
    [[ -z $option ]] && {
      return 1
    }
    echo "$option"
    break
  done
}

utils::maybe_set_login_string() {
  msg="Using ${LOGINSTR:=$(utils::get_cfg_entry logstr)} as login string"
  [[ -z $LOGINSTR ]] && {
    echo "No login string found"
    echo 'Did you forget to run `ec2 connect`?'
    exit 1
  }
  echo "$msg"
}
