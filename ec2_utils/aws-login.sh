#!/bin/bash

source "$(dirname "$0")/utils.sh"

_ECHO() {
  echo -e "\033[0;35m$1\033[0m"
}

infer_login_str() {
  local check_in_str=$1
  [[ -z $check_in_str ]] && {
    check_in_str=$(utils::get_cfg_entry logstr)
    [[ -z $check_in_str ]] && return 1
    echo "$check_in_str"
  }
  if [[ $check_in_str = ec2*amazonaws.com ]]; then
    check_in_str="$EC2_USER@$check_in_str"
  elif [[ $check_in_str != *ec2*amazonaws.com ]]; then
    check_in_str=${check_in_str//./-}
    check_in_str="$EC2_USER@ec2-$check_in_str.compute-1.amazonaws.com"
  fi
  echo "$check_in_str"
}

function login::sanity_checks() {
  local instance_id sshkey user_input=$1
  _LOGINSTR=$(utils::get_cfg_entry logstr)
  instance_id=$(utils::get_cfg_entry instance_id)
  sshkey=$(utils::get_cfg_entry sshkey)

  if [[ -z $user_input ]]; then
    if [[ -z $instance_id ]]; then
      if [[ -z $_LOGINSTR ]]; then
        _ECHO "Try to pick the instance to connect to with the '-p' option."
        _ECHO "You may need to populate the 'instance_ids:-' block in the"
        _ECHO "global config ($HOME_LOGIN_CFG) first."
      fi
    else
      local ec2_state
      ec2_state=$(
        aws ec2 describe-instances \
          --instance-ids "$instance_id" \
          --query 'Reservations[*].Instances[*].State.Name' \
          --output text
      )
      if ! [[ $ec2_state =~ (stopped|running) ]]; then
        _ECHO "The machine is currently in a transient state: '$ec2_state'"
        _ECHO 'Re-run the command in a few seconds'
        _ECHO 'Use the following command to check the status manually:'
        _ECHO 'aws ec2 describe-instances \'
        _ECHO "  --instance-ids $instance_id \\"
        _ECHO '  --query "Reservations[*].Instances[*].State.Name" \'
        _ECHO '  --output text'
        return 1
      fi
      if [[ ${#_ADD_IP4_TO_SG_OPTS[@]} -gt 0 ]]; then
        echo "Managing SSH inbound rules with '${_ADD_IP4_TO_SG_OPTS[*]}'"
      fi
      login::maybe_add_ip4_to_sg "$instance_id" "${_ADD_IP4_TO_SG_OPTS[@]}"
      if [[ $ec2_state = stopped ]]; then
        login::start_ec2_instances "$instance_id"
        echo "Idle until the instance is in 'pending' state.."
        aws ec2 wait instance-running --instance-ids "$instance_id"

        local sleep_time
        sleep_time=$(utils::get_cfg_entry idle_on_first_login)
        sleep_time=${sleep_time:-6}
        echo -n "Idle for another ${sleep_time} seconds"
        echo " for all actions to take effect.."
        sleep "$sleep_time"
      fi
      user_input=$(login::ec2_public_ip_from_instance_id "$instance_id")
      _LOGINSTR=$(infer_login_str "$user_input")
    fi
  elif [[ $_LOGINSTR = $(infer_login_str "$user_input") ]]; then
    ## Likely we are OK since we previously connected to it already.
    echo "Using the cached IP address.."
    return
  elif [[ -z $sshkey ]]; then
    _ECHO "Your setup does not allow to connect to unknown hosts. At least,"
    _ECHO "specify the SSH key in your global config ($HOME_LOGIN_CFG). Even"
    _ECHO "better would be to select the instance to connect to among those"
    _ECHO "listed in the global config under 'instance_ids:-' key"
    return 1
  else
    msg="NOTE: You connect to 'unknown' host (that is, not listed under the"
    msg+="\n'instance_ids' key in the global config file). Make sure to check"
    msg+='\nthe security group of the instance you are connecting to and add'
    msg+='\nthe IP address to the inbound rules manually if need be.'
    local instance_ids
    instance_ids=$(utils::get_cfg_entry instance_ids:- "$HOME_LOGIN_CFG")
    [[ -z $instance_ids ]] && {
      _ECHO "$msg"
      _LOGINSTR=$(infer_login_str "$user_input")
      return
    }
    local found_iid
    while IFS='=' read -r iid pem_file; do
      [[ $pem_file = "$sshkey" ]] && found_iid=$iid
      break
    done <<<"$instance_ids"
    if [[ -z $found_iid ]]; then
      _ECHO "$msg"
      _LOGINSTR=$(infer_login_str "$user_input")
      return
    fi
    local ip4
    _LOGINSTR=$(infer_login_str "$user_input")
    ip4=$(login::ec2_public_ip_from_instance_id "$instance_id")
    if [[ $_LOGINSTR != $(infer_login_str "$ip4") ]]; then
      _ECHO "$msg"
    fi
  fi
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

login::maybe_add_ip4_to_sg() {
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
      ip4=${2:-$ip4}
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
    echo "Select the security group to add the SSH inbound rule to:"
    sg_id=$(utils::select_option "${sg_ids[@]}") || return 1
  fi
  if [[ $revoke_time -le 0 ]]; then
    utils::set_cfg_entry revoke-rule-uri:- "$instance_id=$ip4=$sg_id"
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

## TODO: Remove
function select_instance_old() {
  local choice=$1
  ## TODO: if `choice` is given, no need to call `aws`,
  ## and thus the command can be done much quicker.
  local instance
  local raw_instance_ids
  raw_instance_ids=$(login::get_cfg_entry instance_ids "$HOME_LOGIN_CFG")
  [[ -z ${raw_instance_ids[*]} ]] && {
    echo "No instances to select from"
    echo "Check your 'instance_ids:-' key in $HOME_LOGIN_CFG"
    return 1
  }
  declare -A instance_ids
  declare -A ssh_keys
  while IFS='=' read -r iid pem_file; do
    [[ -z $pem_file ]] && continue
    local iname
    iname=$(
      aws ec2 describe-instances \
        --instance-ids "$iid" \
        --query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
        --output text
    )
    ssh_keys["$iname"]="$pem_file"
    instance_ids["$iname"]="$iid"
  done <<<"$raw_instance_ids"
  [[ -n $choice && $choice != = ]] && {
    choice=${choice#=}
    local _choice=$choice
    [[ $choice -ge 1 ]] && { _choice=$((choice - 1)); }
    declare -a tmp=("${!instance_ids[@]}")
    instance=${tmp[$_choice]}
    [[ -z $instance ]] && {
      echo "No option found with the #'$choice'"
      echo "Available instances:"
      local num=1
      for iid in "${!instance_ids[@]}"; do
        echo "$num) $iid"
        ((num++))
      done
      return 1
    }
    login::set_cfg_entry instance_id "${instance_ids[$instance]}"
    login::set_cfg_entry sshkey "${ssh_keys[$instance]}"
    return 0
  }
  echo "Select the instance to connect to:"
  instance=$(login::select_option "${!instance_ids[@]}") || {
    echo "Invalid selection"
    return 1
  }
  login::set_cfg_entry instance_id "${instance_ids[$instance]}"
  login::set_cfg_entry sshkey "${ssh_keys[$instance]}"
}
