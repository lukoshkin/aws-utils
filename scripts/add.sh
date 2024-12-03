#!/bin/bash

set_up_instance() {
  if [[ $_LOGINSTR = $(infer_login_str "$user_input") ]]; then
    ## Likely we are OK since we previously connected to it already.
    echo "Using the cached IP address.."
    return
  elif [[ -z $sshkey ]]; then
    _ECHO "Your setup does not allow to connect to unknown hosts. At least,"
    _ECHO "specify the SSH key in your main config ($EC2_CFG_MAIN). Even"
    _ECHO "better would be to select the instance to connect to among those"
    _ECHO "listed in the main config under 'instance_opts:-' key"
    return 1
  else
    msg="NOTE: You connect to 'unknown' host (that is, not listed under the"
    msg+="\n'instance_opts' key in the main config file). Make sure to check"
    msg+='\nthe security group of the instance you are connecting to and add'
    msg+='\nthe IP address to the inbound rules manually if need be.'
    local instance_ids
    instance_ids=$(utils::get_cfg_entry instance_ids:- "$EC2_CFG_MAIN")
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
