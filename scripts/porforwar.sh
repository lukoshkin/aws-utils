#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/aws-login.sh"

_help_msg() {
  echo "Usage: $0 [options]"
  echo "Forward ports from a remote host to the client"
  echo
  echo "Options:"
  echo "  --help                    Display this help message"
  echo "  -s, --split               Split 'ssh -N -L .. -L ..' into 'ssh -NL ... &' and 'ssh -NL ... &'"
  echo "  -H HOST, --host HOST      Host to forward the port from. Default: localhost"
  echo "  -p PORT, --port PORT      Port to forward"
}

forward_port() {
  local long_opts="help,split,port:,host:"
  local short_opts="h,s,p:,H:"
  local params

  params=$(getopt -o $short_opts -l $long_opts --name "$0" -- "$@") || {
    echo Aborting..
    return 1
  }
  eval set -- "$params"

  local split=false
  declare -a hosts
  declare -a ports
  while [[ $1 != -- ]]; do
    case $1 in
    -h | --help)
      _help_msg
      return
      ;;
    -s | --split) split=true ;;& # Currently, I doubt it's useful
    -p | --port)
      ports+=("${2#=}")
      shift
      ;;&
    -H | --host)
      hosts+=("${2#=}")
      shift
      ;;&
    *) shift ;;
    esac
  done

  # shellcheck disable=SC2034
  EC2_CFG_FILE=$(utils::get_cfg_entry cfg_file)
  utils::maybe_set_login_string

  declare -a aws_ssh_opts
  aws_ssh_opts=(-i "$(utils::get_cfg_entry sshkey)" "${AWS_SSH_OPTS[@]}")

  if [[ ${#hosts[@]} -gt ${#ports[@]} ]]; then
    echo "Number of ports should be equal to or greater than the hosts thereof"
    return 1
  fi

  declare -a mappings
  for ((i = 0; i < ${#ports[@]}; i++)); do
    local port=${ports[i]}
    local host=${hosts[i]}
    local addr opt_name=L

    if [[ -z $host || $host == localhost ]]; then
      addr="$port:localhost:$port"
    else
      local host1 host2
      host1=$(cut -d: -f1 <<<"$host")
      host2=$(cut -d: -f2 <<<"$host")
      opt_name=$(cut -d: -f3 <<<"$host")
      opt_name=${opt_name:-L}
      [[ -z $host1 ]] && host1=localhost
      [[ -z $host2 ]] && host2=$host1
      addr="$host1:$port:$host2:$port"
    fi
    mappings+=(-"$opt_name" "$addr")
  done
  if $split; then
    for ((i = 0; i < ${#mappings[@]}; )); do
      local opt_name=${mappings[i]}
      local addr=${mappings[i + 1]}
      echo "Forwarding $opt_name $addr ..."
      ssh "${aws_ssh_opts[@]}" -N "$opt_name" "$addr" "$LOGINSTR" &
      ((i += 2))
    done
    wait
  else
    echo "Forwarding ${mappings[*]}..."
    ssh "${aws_ssh_opts[@]}" -N "${mappings[@]}" "$LOGINSTR"
  fi
}

cleanup() {
  pkill -P $$ # Kill all child processes (background jobs)
  exit 0
}

trap cleanup SIGINT
forward_port "$@"
