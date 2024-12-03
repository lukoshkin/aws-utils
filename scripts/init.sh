#!/usr/bin/env bash
source "$(dirname "$0")/dot.sh"
source "$LIB_DIR/utils.sh"

function _check_columns() {
  local columns=(
    "instance_id"
    "sshkey"
    "user"
    "workdir"
    "entrypoint"
  )
  sorted_headers=("$(printf "%s\n" "${@}" | sort)")
  sorted_columns=("$(printf "%s\n" "${columns[@]}" | sort)")
  [[ "${sorted_headers[*]}" = "${sorted_columns[*]}" ]] || {
    >&2 echo "Expected columns: ${columns[*]}"
    >&2 echo "Actual columns: ${headers[*]}"
    return 1
  }
}

function init() {
  # EC2_CFG_FILE= # We could have shown explicitly the var is empty
  mkdir -p "$EC2_CFG_FOLDER"
  {
    IFS="|" read -r -a headers
    _check_columns "${headers[@]}" || return 1

    local num=0
    while IFS='|' read -r -a values; do
      declare -A instance_opts
      for i in "${!headers[@]}"; do
        instance_opts["${headers[$i]}"]="${values[$i]}"
      done

      local name
      local instance_id=${instance_opts[instance_id]}
      utils::valid_instance_id_check "$instance_id" || return 1
      name=$(
        aws ec2 describe-instances \
          --instance-ids "$instance_id" \
          --query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
          --output text
      ) || name=""

      local file suffix="$name%$instance_id"
      file=$(utils::unique_file_by_affix suffix "$suffix") || return 1
      [[ -z $name ]] && {
        if [[ -n $file ]]; then
          EC2_CFG_FILE=$file
          utils::set_cfg_entry state "missing"
          echo "Instance '$instance_id' has the dedicated config file, however"
          echo "it is missing on the AWS side. Mend the instance ID first and"
          echo "then call 'init' command again. You can also remove it"
          echo "if no longer needed."
        fi
        continue
      }

      ((num++))
      if [[ -n $file ]]; then
        mv "$EC2_CFG_FOLDER/"{"$file","$num%$suffix"} 2>/dev/null
      fi

      local connection
      # shellcheck disable=SC2034
      EC2_CFG_FILE=$num%$suffix
      connection=$(utils::get_cfg_entry connection)
      utils::set_cfg_entry connection "${connection:-exists}"

      for key in "${!instance_opts[@]}"; do
        utils::set_cfg_entry "$key" "${instance_opts[$key]}"
      done
      echo "✅ $name"
    done
  } < <(utils::get_cfg_entry instance_opts | sed '$d')
}

init "$@"