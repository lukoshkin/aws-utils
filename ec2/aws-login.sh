#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

function infer_login_str() {
  local check_in_str=$1
  [[ -z $check_in_str ]] && {
    check_in_str=$(utils::get_cfg_entry logstr)
    [[ -z $check_in_str ]] && return 1
    echo "$check_in_str"
  }
  local ec2_user
  ec2_user=$(utils::ec2_user)
  if [[ $check_in_str = ec2*amazonaws.com ]]; then
    check_in_str="$ec2_user@$check_in_str"
  elif [[ $check_in_str != *ec2*amazonaws.com ]]; then
    check_in_str=${check_in_str//./-}
    check_in_str="$ec2_user@ec2-$check_in_str.compute-1.amazonaws.com"
  fi
  echo "$check_in_str"
}

function login::sanity_checks_and_setup_finalization() {
  local skip_checks=${_SKIP_CHECKS:-false}
  if $skip_checks; then
    LOGINSTR=$(utils::get_cfg_entry logstr)
    [[ -n $LOGINSTR ]] && {
      echo "Using the cached login and host string.."
      utils::warn "Note this case, no guarantee the string is up to date"
      echo "For a safer login, omit the '-s' flag."
      return
    }
    echo "Not able to skip the sanity checks, since "
    echo "the cached login and host string is not found."
    _SKIP_CHECKS=false
  fi
  $skip_checks || echo "To skip the sanity checks, use '-s' flag"
  local instance_id
  instance_id=$(utils::get_cfg_entry instance_id)
  [[ -z $instance_id ]] && {
    utils::info "Hmm, curious.. There is no 'instance_id' in $EC2_CFG_FILE"
    utils::info "Try to mend this with 'ec2 init' call."
    return 1
  }
  local ec2_state
  ec2_state=$(
    aws ec2 describe-instances \
      --instance-ids "$instance_id" \
      --query 'Reservations[*].Instances[*].State.Name' \
      --output text
  )
  if ! [[ $ec2_state =~ (stopped|running) ]]; then
    utils::info "The machine is currently in a transient state: '$ec2_state'"
    utils::info "One can monitor the machine state with 'ec2 ls' command"
    return 1
  fi
  if [[ ${#_ADD_IP4_TO_SG_OPTS[@]} -gt 0 ]]; then
    echo "Managing SSH inbound rules with '${_ADD_IP4_TO_SG_OPTS[*]}'"
    login::clean_up "$instance_id"
  fi
  local ip4 # client's IP4
  ip4=$(utils::get_cfg_entry revoke-rule-uri)
  ip4=$(cut -d% -f2 <<<"$ip4")

  if [[ -z $ip4 ]]; then
    login::maybe_add_ip4_to_sg "$instance_id" "${_ADD_IP4_TO_SG_OPTS[@]}"
  elif ! [[ $ip4 = $(curl -s ifconfig.me)/32 ]]; then
    if ! [[ $ip4 = 0.0.0.0/0 ]]; then
      utils::error "The current IP address is not white-listed"
      utils::set_cfg_entry connection "blocked"
    fi
  fi

  if [[ $ec2_state = stopped ]]; then
    login::start_ec2_instances "$instance_id"
    echo "Idle until the instance is in 'pending' state.."
    aws ec2 wait instance-running --instance-ids "$instance_id"
    utils::set_cfg_entry state "running"

    local sleep_time
    sleep_time=$(utils::get_cfg_entry idle_on_first_login)
    sleep_time=${sleep_time:-6}
    echo -n "Idle for another ${sleep_time} seconds"
    echo " for all actions to take effect.."
    sleep "$sleep_time"
  fi
  local ip4 # host
  ip4=$(login::ec2_public_ip_from_instance_id "$instance_id")
  LOGINSTR=$(infer_login_str "$ip4")
}

login::start_ec2_instances() {
  for instance_id in "$@"; do
    utils::valid_instance_id_check "$instance_id" || return $?
  done

  aws ec2 start-instances --instance-ids "$@"
}

login::revoke_ssh_inbound_rule() {
  local sg_id=$1 ip4=$2
  aws ec2 revoke-security-group-ingress \
    --group-id "$sg_id" \
    --protocol tcp \
    --port 22 \
    --cidr "$ip4" 2> >(tee -a "$(utils::ec2_log_file)") >/dev/null
  echo "The ssh access for '$ip4' has been revoked"
}

login::maybe_add_ip4_to_sg() {
  local short_opts="n,t:"
  local long_opts="non-interactive,revoke-time:,ip:"
  local params
  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 2
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
      local _ip4=${2#=}
      ip4=${_ip4:-$ip4}
      shift 2
      ;;
    -t | --revoke-time)
      revoke_time=$2
      shift 2
      ;;
    *)
      echo Impl.error
      return 2
      ;;
    esac
  done

  shift
  utils::valid_instance_id_check "$1" || return $?
  local instance_id=$1

  echo "Checking the inbound rules for the instance.."
  declare -a sg_ids
  mapfile -t sg_ids < <(
    aws ec2 describe-instances \
      --instance-ids "$instance_id" \
      --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
      --output text | tr -s ' \t' '\n'
  )
  local all_ip4s
  all_ip4s=$(
    aws ec2 describe-security-groups \
      --group-ids "${sg_ids[@]}" \
      --query 'SecurityGroups[].IpPermissions[?FromPort==`22` && ToPort==`22`].IpRanges[*].CidrIp' \
      --output text
  )
  [[ $all_ip4s = *"$ip4"* || $all_ip4s = *0.0.0.0/0* ]] && {
    echo "$ip4 is white-listed already"
    return
  }
  echo "$ip4 is not in the SSH inbound rules; thus, will be added"

  local sg_id
  if [[ ${#sg_ids[@]} -eq 1 || $non_interactive ]]; then
    sg_id=${sg_ids[0]}
  else
    PS3="Select the security group to add the SSH inbound rule to:"
    sg_id=$(utils::select_option "${sg_ids[@]}") || return $?
  fi
  if [[ $revoke_time -le 0 ]]; then
    utils::set_cfg_entry revoke-rule-uri "$instance_id%$ip4%$sg_id"
  else
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
    --cidr "$ip4" 2> >(tee -a "$(utils::ec2_log_file)") >/dev/null
}

function login::ec2_public_ip_from_instance_id() {
  utils::valid_instance_id_check "$1" || return $?
  local instance_id=$1
  aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
}

function login::clean_up() {
  local revoke_rule_uri instance_id=$1
  echo "Searching the inbound rules added by ec2.."
  revoke_rule_uri=$(utils::get_cfg_entry revoke-rule-uri:-)
  [[ -z $revoke_rule_uri ]] && {
    echo "No rules found."
    return
  }
  IFS=% read -r iid ip4 sg_id <<<"$revoke_rule_uri"
  [[ $# -gt 0 && $iid != "$instance_id" ]] && {
    utils::error "Instance ID validation mismatch"
    return 2
  }
  login::revoke_ssh_inbound_rule "$sg_id" "$ip4" && {
    utils::set_cfg_entry revoke-rule-uri
    echo "Cleaned up!"
  }
}
