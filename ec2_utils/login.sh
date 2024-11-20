#!/bin/bash

CUSTOM_ES=21 # custom exit status
HOME_LOGIN_CFG=${EC2_LOGIN_CFG_PATH:-~/.ec2_login_opts}
TMP_LOGIN_CFG=/tmp/ec2_$USER-last_login_opts

login::get_cfg_entry() {
  local key=$1
  [[ -f ${2:-$TMP_LOGIN_CFG} ]] || return
  grep -q "^$key:-" "${2:-$TMP_LOGIN_CFG}" && {
    sed -n "/^$key:-/,/^$/p" "${2:-$TMP_LOGIN_CFG}" | sed -n '1!p'
    return
  }
  sed -r "s;$key: (.*);\1;" <<<"$(grep "^$key:" "${2:-$TMP_LOGIN_CFG}")"
}

login::set_cfg_entry() {
  local key=$1
  local value=$2
  if [[ -f $TMP_LOGIN_CFG ]] && grep -q "^$key:" "$TMP_LOGIN_CFG"; then
    [[ $# -eq 1 ]] && {
      sed -ri "/^$key:/d" "$TMP_LOGIN_CFG"
      return
    }
    sed -ri "s;^$key: .*;$key: $value;" "$TMP_LOGIN_CFG"
  else
    [[ $# -eq 1 ]] && return
    echo "$key: $value" >>"$TMP_LOGIN_CFG"
  fi
}

EC2_USER=$(login::get_cfg_entry user "$HOME_LOGIN_CFG")
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

login::select_option() {
  select option in "$@"; do
    [[ -z $option ]] && {
      echo "No option selected"
      return 1
    }
    echo "$option"
    break
  done
}

login::maybe_set_login_string() {
  msg="Using ${LOGINSTR:=$(login::get_cfg_entry logstr)} as login string"
  [[ -z $LOGINSTR ]] && {
    echo "No login string found"
    echo 'Did you forget to run `ec2 connect`?'
    exit 1
  }
  echo "$msg"
}

valid_instance_id_check() {
  [[ $1 =~ ^i- ]] || {
    echo "Invalid instance id: <$1>"
    return 1
  }
}

login::start_ec2_instances() {
  for instance_id in "$@"; do
    valid_instance_id_check "$instance_id" || return 1
  done

  aws ec2 start-instances --instance-ids "$@"
}

login::revoke_ssh_inbound_rule() {
  local sg_id=$1 ip4=$2
  aws ec2 revoke-security-group-ingress \
    --group-id "$sg_id" \
    --protocol tcp \
    --port 22 \
    --cidr "$ip4" 2> >(tee -a "$TMP_LOGIN_LOG") >/dev/null
  echo "The ssh access for '$ip4' has been revoked"
}

login::add_ip4_to_sg() {
  local short_opts="n,t:"
  local long_opts="non-interactive,revoke-time:,ip:"
  local params
  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return "$CUSTOM_ES"
  }
  eval set -- "$params"

  local non_interactive ip4 revoke_time=-1
  ip4="$(curl -s ifconfig.me)/32"
  while [[ $1 != -- ]]; do
    case $1 in
    -n | --non-interactive)
      non_interactive=true
      shift
      ;;
    --ip)
      ip4=$2
      shift 2
      ;;
    -t | --revoke-time)
      revoke_time=$2
      shift 2
      ;;
    *)
      echo Impl.error
      return 1
      ;;
    esac
  done

  shift
  valid_instance_id_check "$1" || return 1

  local instance_id=$1
  declare -a sg_ids
  mapfile -t sg_ids < <(
    aws ec2 describe-instances \
      --instance-ids "$instance_id" \
      --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
      --output text | tr -s ' \t' '\n'
  )
  local sg_id
  if [[ ${#sg_ids[@]} -eq 1 || $non_interactive ]]; then
    sg_id=${sg_ids[0]}
  else
    echo "Select the security group to add the SSH inbound rule to:"
    sg_id=$(login::select_option "${sg_ids[@]}") || return 1
  fi
  login::set_cfg_entry revoke-rule-uri "$ip4%$sg_id"
  if [[ $revoke_time -gt 0 ]]; then
    echo "Revoking the ssh access for '$ip4' in $revoke_time seconds"
    {
      sleep "$revoke_time"
      login::revoke_ssh_inbound_rule "$sg_id" "$ip4"
    } &
  fi
  aws ec2 authorize-security-group-ingress \
    --group-id "$sg_id" \
    --protocol tcp \
    --port 22 \
    --cidr "$ip4" 2> >(tee -a "$TMP_LOGIN_LOG") >/dev/null
}

login::ec2_public_ip_from_instance_id() {
  valid_instance_id_check "$1" || return 1
  local instance_id=$1
  aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
}
