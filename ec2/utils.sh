#!/bin/bash

EC2_FOLDER=$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")
EC2_CFG_FOLDER=$EC2_FOLDER/ec2_login_opts
EC2_CFG_MAIN=$EC2_FOLDER/main.cfg
# EC2_CFG_FILE=

_cfg() {
  [[ -z $1 || $1 = "$EC2_CFG_MAIN" ]] && [[ -z $EC2_CFG_FILE ]] && {
    echo "$EC2_CFG_MAIN"
    return
  }
  echo "$EC2_CFG_FOLDER/${1:-$EC2_CFG_FILE}"
}

utils::info() {
  echo -e "$(utils::c "$1" 35)"
}

utils::unique_file_by_affix() {
  local folder=${3:-$EC2_CFG_FOLDER}
  folder="${folder%/}"
  [[ -d $folder ]] || {
    >&2 echo "No such directory: $folder"
    return 1
  }
  local prefix=$2
  local file
  case $1 in
  prefix)
    file=("$folder/"*"$prefix")
    ;;
  suffix)
    file=("$folder/$prefix"*)
    ;;
  infix)
    file=("$folder/"*"$prefix"*)
    ;;
  *)
    >&2 echo "Unknown affix: $2"
    return 2
    ;;
  esac

  if [[ ${#file[@]} -gt 1 ]]; then
    >&2 echo "Impl.error: the file is not unique"
    >&2 echo "Multiple files found with the prefix $prefix:"
    for path in "${file[@]}"; do
      >&2 echo -n "$(realpath --relative-to "$folder" "$path") "
    done
    return 1
  fi

  if [[ -f ${file[0]} ]]; then
    realpath --relative-to "$folder" "${file[0]}"
  fi
}

utils::get_cfg_entry() {
  local key=${1%:}
  local key=${key%:-}
  local cfg
  cfg=$(_cfg "$2")

  [[ -f $cfg ]] || return
  grep -q "^$key:-" "$cfg" && {
    sed -n "/^$key:-/,/^$/p" "$cfg" | sed -n '1!p'
    return
  }
  sed -r "s;$key: (.*);\1;" < <(grep "^$key:" "$cfg")
}

utils::set_cfg_entry() {
  [[ $# -eq 2 && -z $2 ]] && return
  local key=${1%:}
  local value=$2
  local cfg
  cfg=$(_cfg)

  if [[ -f $cfg ]] && grep -q "^${key%:-}:" "$cfg"; then
    [[ $# -eq 1 ]] && {
      if [[ $key =~ :-$ ]]; then
        sed -ri "/^$key/,/^$/d" "$cfg"
      else
        grep -q "^$key:-" "$cfg" && return
        sed -ri "/^$key:/d" "$cfg"
      fi
      return
    }
    if [[ $key =~ :-$ ]]; then
      sed -ri "/^$key/,/^$/ { /^$/ {s/^/$value\n/; } }" "$cfg"
    else
      sed -ri "s;^$key: .*;$key: $value;" "$cfg"
    fi
  else
    [[ $# -eq 1 ]] && return
    if [[ $key = *:- ]]; then
      echo "$key" >>"$cfg"
      echo -e "$value\n" >>"$cfg"
    else
      echo "$key: $value" >>"$cfg"
    fi
  fi
}

function utils::ec2_log_file() {
  echo "/tmp/ec2_$USER-$(utils::get_cfg_entry user)-last_login.log"
}

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

utils::valid_instance_id_check() {
  [[ $1 =~ ^i- ]] || {
    >&2 echo "Invalid instance id: <$1>"
    return 1
  }
}

utils::strip_quotes() {
  local str=$1
  str=${str//'"'/}
  str=${str//"'"/}
  echo "$str"
}

utils::select_option() {
  select option in "$@"; do
    [[ -z $option ]] && {
      >&2 echo "Invalid selection"
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

utils::c() {
  local text=$1
  local reset="\033[0m"
  shift

  local fg=$1
  local ta=${2:-$_TEXT_ATTR}
  local bg=${3:-$_BG_COLOR}

  if [[ -n $bg ]]; then
    echo "\033[${ta:-0};${fg};${bg}m$text$reset"
  fi
  echo "\033[${ta:-0};${fg}m$text$reset"
}
