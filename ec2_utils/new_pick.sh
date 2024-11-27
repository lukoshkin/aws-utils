source "$(dirname "$0")/utils.sh"

function select_instance() {
  local instances
  instances=$(ls $EC2_CFG_FOLDER)
  [[ -z $instances ]] && {
    echo "No config to set up a connection from!"
    echo "Check your 'instance_opts:-' key in $EC2_CFG_FOLDER"
    echo "If it is OK, run 'ec2 init' to create configs"
    return 1
  }
  local _choice choice=$1
  [[ -n $choice && $choice != = ]] && {
    choice=${choice#=}
    local _choice=$choice
    [[ $choice -ge 1 ]] && { _choice=$((choice - 1)); }
  }
  declare -A instance_map
  declare -a names
  while IFS='%' read -r instance_id name num; do
    instance_map[$name]=$EC2_CFG_FOLDER/$instance_id%$name$num
    names+=("$name")
  done <<<"$instances
}
