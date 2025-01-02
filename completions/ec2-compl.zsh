_ec2_completions() {
  local -a subcommands
  subcommands=(
    'connect:Connect to an EC2 instance'
    'pick:Select an instance to continue with'
    'scp-file:Transfer files to or from an EC2 instance'
    'sync:Sync the host folder on an EC2 instance with the local counterpart'
    'porforwar:Port forward from an EC2 instance'
    'clean-up:Clear SSH inbound rules added earlier by ec2'
    'disconnect:Disconnect from the EC2 instance'
    'install-completions:Install completions for the ec2 command'
  )
  _arguments -A "-*" \
    '1:Subcommand:->subcommands' \
    '*:: :->remaining'

  case "$state" in
    subcommands)
      _describe 'subcommands' subcommands
      ;;
    remaining)
      case "${line[1]}" in
        connect)
          _arguments \
            '(-h --help)'{-h,--help}'[Show help message]' \
            '(-p --pick-instance)'{-p+,--pick-instance=}'[Pick the instance to connect to]' \
            '(-d --detach)'{-d,--detach}'[Do not start interactive session]' \
            '(-e --execute)'{-e+,--execute=}'[Execute command after connecting]::_nothing' \
            '(--ip)--ip=[Manually specify the IP for the SSH inbound rule to add]' \
            '(-t --revoke-time)'{-t+,--revoke-time=}'[Revoke the added SSH inbound rule after the provided time in seconds]::_nothing'
          ;;
        scp-file)
          _arguments \
            '(-h --help)'{-h,--help}'[Show help message]' \
            '(-t --tar)'{-t,--tar}'[Tar the folder being transferred]' \
            '(-z --gzip)'{-z,--gzip}'[Gzip the tarred folder]' \
            '1:Source directory:_files' \
            '2:Target directory:_files'
          ;;
        sync)
          _arguments \
            '(-h --help)'{-h,--help}'[Show help message]' \
            '(-a --all-files)'{-a,--all-files}'[Sync over all files on the client]' \
            '(-e --execute)'{-e+,--execute=}'[Execute command after sync]::_nothing' \
            '(-n --dry-run)'{-n,--dry-run}'[Show changes without applying them]' \
            '--client-always-right[Update with client files even if their modify-times are older]' \
            '1:Source directory:_files -/' \
            '2:Target directory:_files -/'
          ;;
        install-completions)
          _arguments '1:Path to shellrc file:_files'
          ;;
        *)
          _message "No specific completions for this subcommand"
          ;;
      esac
      ;;
  esac
}

compdef _ec2_completions ec2
