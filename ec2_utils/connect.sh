#!/bin/bash

source "$(dirname "$0")/login.sh"

function help_msg() {
  echo "Usage: $0 [OPTIONS] [login_and_host]"
  echo "Connect to the specified EC2 instance"
  echo
  echo "Options:"
  echo "  -h, --help               Show this help message and exit"
  echo "  -e CMD, --execute CMD    Execute the command on the remote machine"
  echo "  -d, --detach             Do not log in on the host"
  echo
  echo '  [beta]'
  echo "  --ip IP                             Manually specify the IP for the SSH inbound rule to add"
  echo "  -t TIME, --revoke-time TIME         Specify the time in seconds to revoke the added SSH inbound rule"
  echo "  -p=[NUM], --pick-instance=[NUM]     Pick the instance to connect to"
  echo "  -n, --non-interactive               A security group auto-select (may be extended later)"
}

function strip_quotes() {
  local str=$1
  str=${str//'"'/}
  str=${str//"'"/}
  echo "$str"
}

function process_login_str() {
  local check_in_str=$1
  if [[ -z $check_in_str ]]; then
    check_in_str=$(login::get_cfg_entry logstr)
    [[ -z $check_in_str ]] && {
      >&2 echo Provide 'login_and_host' argument
      return 1
    }
    echo "$check_in_str"
    return 0
  fi

  if [[ $check_in_str = ec2*amazonaws.com ]]; then
    check_in_str="$EC2_USER@$check_in_str"
  elif [[ $check_in_str != *ec2*amazonaws.com ]]; then
    check_in_str=${check_in_str//./-}
    check_in_str="$EC2_USER@ec2-$check_in_str.compute-1.amazonaws.com"
  fi
  echo "$check_in_str"
}

function select_instance() {
  local choice=$1
  local instance_id
  declare -A instance_ids
  while IFS='=' read -r instance pem_file; do
    instance_ids["$instance"]="$pem_file"
  done <<<"$(login::get_cfg_entry instance_ids "$HOME_LOGIN_CFG")"
  [[ -z ${instance_ids[*]} ]] && {
    echo "No instances found in the global config file ($HOME_LOGIN_CFG)"
    return 1
  }
  [[ -n $choice && $choice != = ]] && {
    choice=${choice#=}
    local _choice=$choice
    [[ $choice -ge 1 ]] && { _choice=$((choice - 1)); }
    instance_id=${!instance_ids[$_choice]}
    [[ -z $instance_id ]] && {
      echo "No instance found with the id '$choice'"
      echo "Available instances:"
      local num=1
      for instance in "${!instance_ids[@]}"; do
        echo "$num) $instance"
        ((num++))
      done
      return 1
    }
    login::set_cfg_entry instance_id "$instance_id"
    return 0
  }
  instance_id=$(login::select_option "${!instance_ids[@]}") || return 1
  login::set_cfg_entry instance_id "$instance_id"
  login::set_cfg_entry sshkey "${instance_ids[$instance_id]}"
}

function connect() {
  local long_opts="non-interactive,pick-instance:,execute:,detach,ip:,revoke-time:,help"
  local short_opts="n,p:,e:,d,t:,h"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return "$CUSTOM_ES"
  }
  eval set -- "$params"

  declare -a add_ip4_to_sg_opts
  local exec_cmd detach=false clear_logstr=false
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      help_msg
      return
      ;;
    -p | --pick-instance | -d | --detach | -t | --ip | --revoke-time)
      clear_logstr=true
      ;;&
    -p | --pick-instance)
      echo "Select the instance to connect to:"
      select_instance "$2" || return 1
      shift 2
      ;;
    -d | --detach)
      detach=true
      shift
      ;;
    -e | --execute)
      detach=true
      exec_cmd="$2"
      shift 2
      ;;
    -t | --ip | --revoke-time)
      add_ip4_to_sg_opts+=("$1" "$2")
      shift 2
      ;;
    -n | --non-interactive)
      add_ip4_to_sg_opts+=("$1")
      shift
      ;;
    *)
      echo Impl.error
      return 1
      ;;
    esac
  done

  shift
  if [[ ! -f $TMP_LOGIN_CFG && -f $HOME_LOGIN_CFG ]]; then
    cp "$HOME_LOGIN_CFG" "$TMP_LOGIN_CFG"
  fi

  if $clear_logstr; then
    login::set_cfg_entry 'logstr'
  fi

  local instance_id user_input="$1"
  user_input=${user_input:-$(login::get_cfg_entry logstr)}
  instance_id=$(login::get_cfg_entry instance_id)

  if [[ -z $instance_id ]]; then
    echo -e "\033[0;35m"
    echo "Check the id of the EC2 instance you are connecting to and add it"
    echo "under 'instance_ids' key to the global config file ($HOME_LOGIN_CFG)"
    echo "to automatically add dynamic IP to the security group inbound rules"
    echo -e "\033[0m"
  elif [[ -z $user_input ]]; then
    local ec2_state
    ec2_state=$(
      aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].State.Name' \
        --output text
    )
    if ! [[ $ec2_state =~ (stopped|running) ]]; then
      echo "The machine is currently in a transient state: $ec2_state"
      echo 'Re-run the command in a few seconds'
      echo 'Use the following command to check the status manually:'
      echo 'aws ec2 describe-instances \'
      echo "  --instance-ids $instance_id \\"
      echo '  --query "Reservations[*].Instances[*].State.Name" \'
      echo '  --output text'
      return 1
    fi
    if [[ $ec2_state = stopped ]]; then
      login::start_ec2_instances "$instance_id"
      login::add_ip4_to_sg "$instance_id" "${add_ip4_to_sg_opts[@]}"
      echo "Idle until the instance is in 'pending' state.."
      aws ec2 wait instance-running --instance-ids "$instance_id"

      local sleep_time
      sleep_time=$(login::get_cfg_entry idle_on_first_login)
      sleep_time=${sleep_time:-6}
      echo -n "Idle for another ${sleep_time} seconds"
      echo " for all actions to take effect.."
      sleep "$sleep_time"
    elif [[ ${#add_ip4_to_sg_opts[@]} -gt 0 ]]; then
      echo "Managing the security group inbound rules with ${add_ip4_to_sg_opts[*]}"
      login::add_ip4_to_sg "$instance_id" "${add_ip4_to_sg_opts[@]}"
    fi
    user_input=$(login::ec2_public_ip_from_instance_id "$instance_id")
  fi

  local login_and_host workdir
  login_and_host="$(process_login_str "$user_input")" || return 1
  entrypoint=$(login::get_cfg_entry entrypoint)
  entrypoint=${entrypoint:-':'}
  entrypoint=$(strip_quotes "$entrypoint")
  workdir=${WORKDIR:-$(login::get_cfg_entry workdir)}
  workdir=${workdir:-'~'}
  workdir=$(strip_quotes "$workdir")

  echo "Connecting to <$login_and_host>"
  echo "Working directory is '$workdir'"
  echo "Entrypoint cmd: '$entrypoint'"
  echo '---'

  declare -a aws_ssh_opts
  aws_ssh_opts=(-i "$(login::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

  if [[ -n $entrypoint && $entrypoint != ':' ]]; then
    timeout "${TIMEOUT:-20}" ssh "${aws_ssh_opts[@]}" \
      "$login_and_host" "$entrypoint &>>$TMP_LOGIN_LOG" || {
      echo Was not able to start the project containers!
      echo -n "Check the network connection or that you typed"
      echo " in the correct 'login_and_host' string!"
      # Setting `TIMEOUT=` var empty will ignore the command execution status
      [[ -z ${TIMEOUT+any} || -n ${TIMEOUT} ]] && exit 1
    }
  fi
  login::set_cfg_entry 'logstr' "$login_and_host"
  login::set_cfg_entry 'workdir' "$workdir"
  if ! $detach; then
    ssh -tA "${aws_ssh_opts[@]}" -o ServerAliveInterval=100 "$login_and_host" \
      "cd $workdir &>>$TMP_LOGIN_LOG; exec \$SHELL"
    # -t to set a working directory and run interactive session from it
    # -A to forward your '.ssh' folder
    return
  fi
  if [[ -n $exec_cmd ]]; then
    echo "Executing command: <$exec_cmd>"
    ssh -A "${aws_ssh_opts[@]}" "$login_and_host" \
      "{ cd $workdir; bash -c '$exec_cmd'; } |& tee -a $TMP_LOGIN_LOG"
  fi
  echo -e "\nDetaching.."
}

connect "$@"
