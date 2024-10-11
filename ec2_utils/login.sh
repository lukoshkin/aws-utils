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

login::add_ip4_to_sg() {
  valid_instance_id_check "$1" || return 1

  local ip4
  local instance_id=$1
  ip4=$(curl -s ifconfig.me)

  local sg_id
  sg_id=$(
    aws ec2 describe-instances \
      --instance-ids "$instance_id" \
      --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
      --output text
  )
  aws ec2 revoke-security-group-ingress \
    --group-id "$sg_id" \
    --protocol tcp \
    --port 22 \
    --cidr "$ip4/32" &>/dev/null
  aws ec2 authorize-security-group-ingress \
    --group-id "$sg_id" \
    --protocol tcp \
    --port 22 \
    --cidr "$ip4/32" &>/dev/null
}

login::ec2_public_ip_from_instance_id() {
  valid_instance_id_check "$1" || return 1
  local instance_id=$1
  aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
}

EC2_USER=$(login::get_cfg_entry user $HOME_LOGIN_CFG)
EC2_USER=${EC2_USER:-'ubuntu'}
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
