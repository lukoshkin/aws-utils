# AWS CLI Utils

Easy management of AWS EC2 instances

## Usage

1. **Connect** (or resume and connect) to an EC2 instance

   ```bash
   ec2 connect  # using the value of `instance_id` key in '~/.ec2_login_opts'
   ec2 connect 10.111.101.01  # using IP4 (caches also "login and host string" to '/tmp/ec2_last_login_opts')
   ec2 connect ubuntu@ec2-10-111-101-01.compute-1.amazonaws.com  # using "login and host string"
   ec2 connect  # using the cached value of "login and host string"
   ```

   Note that `connect` can add the proper inbound rule for ssh-connections for
   your dynamic IP4 if you specify the instance id in the `~/.ec2_login_opts`.

2. **Transfer files**

   ```bash
   ec2 scp-file '~/table.csv' /tmp  # download /home/ubuntu/table.csv from the host
   UPLOAD= ec2 scp-file ~/new-table.csv /tmp  # upload $HOME/new-table.csv to host's /tmp
   ec2 scp-file -tz '~/datadir' . # download by tarring (`-t` - required for a folder) and compressing (`-z`) the folder
   ```

   One can configure default destination paths for uploads and downloads in `~/.ec2_login_opts`.  
   (Not implemented yet.)

3. **Forward ports** (Por favor)
   ```bash
   ec2 porfowar  # default port is 6006
   PORT=8080 ec2 porfowar
   ```

## Installation

1. With `curl` _(preferred)_
   ```bash
   curl -fsSL https://raw.githubusercontent.com/lukoshkin/aws-utils/refs/heads/master/install.sh | bash
   ```
2. With `git`
   ```bash
   git clone https://github.com/lukoshkin/aws-utils.git
   INSTALL_PATH=$XDG_CONFIG_HOME/aws-utils bash install.sh
   ```
   `$XDG_CONFIG_HOME/aws-utils` is a default folder when running the
   `install.sh` from outside of directory (useful for the previous approach).
   If executing withing the git-folder then it is `$PWD`.
3. Custom installation by linking to another place that's on the `$PATH`.
   For example, if someone prefers to keep executables in `$HOME/.local/bin`:
   ```bash
   git clone https://github.com/lukoshkin/aws-utils.git
   ln -s "$(readlink -f ec2.sh)" $HOME/.local/bin/ec2
   ```

## TODO

- [x] Add README
- [x] Add `ec2` executable
- [x] Add installation
- [ ] Add customization of defaults in `~/.ec2_login_opts`
- [ ] Add `disconnect` subcommand  
       (unlike `sudo shutdown -h now` on the host, it should also manage  
       clearing the cached values in `/tmp/ec2_last_login_opts`)
- [ ] Manage more than one EC2 instance
- [ ] Rename/move/migrate to "aws-cli-utils"?
