_ec2_completions() {
  local -a subcommands
  subcommands=(
    'connect:Connect to an EC2 instance'
    'pick:Select an instance to continue with'
    'scp-file:Transfer files to or from an EC2 instance'
    'sync:Sync the host folder on an EC2 instance with the local counterpart'
    'execute:Execute a command on an EC2 instance'
    'porforwar:Port forward from an EC2 instance'
    'clean-up:Clear SSH inbound rules added earlier by ec2'
    'disconnect:Disconnect from an EC2 instance'
    'add:Add an entry of a new EC2 instance for further initialization'
    'init:Create configuration files for all entries in the main.cfg'
    'set-up-user:Create a new user on an EC2 instance and set up the login w/o password'
    'info:Pull information about EC2 instances and their states'
    'ls:Alias for info, list info about EC2 instances'
    'home:Show the path to the ec2 folder'
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
    local -a help_option=(
      '(-h --help)'{-h,--help}'[Show help message and exit]'
    )
    local -a pick_option=(
      '(-p --pick)'{-p+,--pick=}'[Pick instance by number/index]'
    )

    case "${line[1]}" in
    connect)
      _arguments \
        "${help_option[@]}" \
        "${pick_option[@]}" \
        '(-c --cache-opts)'{-c,--cache-opts}'[Cache these options for next connection]' \
        '(-d --detach)'{-d,--detach}'[Do not start an interactive session]' \
        '(-e --entrypoint)'{-e+,--entrypoint=}'[Command to execute after connecting]::_nothing' \
        '(--ip)--ip=[Manually specify the IP for the SSH inbound rule]' \
        '(-n --non-interactive)'{-n,--non-interactive}'[Run commands non-interactively]' \
        '(-s --skip-checks)'{-s,--skip-checks}'[Skip checks necessary on the first login]' \
        '(-t --revoke-time)'{-t+,--revoke-time=}'[Revoke the SSH inbound rule after specified seconds]::_nothing'
      ;;

    scp-file)
      _arguments \
        "${help_option[@]}" \
        "${pick_option[@]}" \
        '(-u --upload)'{-u,--upload}'[Upload file(s) to instance (instead of downloading)]' \
        '(-t --tar)'{-t,--tar}'[Tar the folder before transferring]' \
        '(-z --gzip)'{-z,--gzip}'[Compress tarball with gzip]' \
        '1:Source directory or file:_files' \
        '2:Target directory:_files'
      ;;

    sync)
      _arguments \
        "${help_option[@]}" \
        "${pick_option[@]}" \
        '(-a --all-files)'{-a,--all-files}'[Sync all files on the client side]' \
        '(-e --execute)'{-e+,--execute=}'[Run a command after syncing]::_nothing' \
        '(-n --dry-run)'{-n,--dry-run}'[Show changes without applying them]' \
        '--client-always-right[Force client files as the correct copy]' \
        '1:Source directory:_files -/' \
        '2:Target directory:_files -/'
      ;;

    porforwar)
      _arguments \
        "${help_option[@]}" \
        "${pick_option[@]}" \
        '(-s --split)'{-s,--split}'[Split "ssh -N -L ..." into separate background processes]' \
        '(-H --host)'{-H+,--host=}'[Remote host (default: localhost)]' \
        '(-P --port)'{-P+,--port=}'[Port to forward]'
      ;;

    disconnect)
      _arguments \
        "${help_option[@]}" \
        "${pick_option[@]}" \
        '(-a --via-exec)'{-a,--via-exec}'[Run "sudo shutdown -h now" on the instance]' \
        '--no-cleanup[Skip cleanup after disconnect]'
      ;;

    execute)
      _arguments \
        "${help_option[@]}" \
        "${pick_option[@]}" \
        '-A[Forward SSH agent]' \
        '(-e --extend-session)'{-e,--extend-session}'[Extend the session time]' \
        '(-E --E)'{-E+,--E=}'[Set session time to NUM seconds]::_numbers' \
        '(-w --workdir)'{-w+,--workdir=}'[Change to DIR before executing command]::_files -/' \
        '(-n --no-sep)'{-n,--no-sep}'[Do not print separator before and after command output]' \
        '-v[Enable verbose mode]'
      ;;

    info|ls) _arguments "${help_option[@]}" \
      '(-b --non-blocking)'{-b,--non-blocking}'[Do not block the terminal while fetching the info]'
      ;;

    add) _arguments "${help_option[@]}" ;;
    set-up-user) _arguments "${help_option[@]}" "${pick_option[@]}" ;;
    install-completions) _arguments '1:Path to shellrc file:_files' ;;
    *) _message "No specific completions for this subcommand" ;;
    esac
    ;;
  esac
}

compdef _ec2_completions ec2
