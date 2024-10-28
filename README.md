# AWS CLI Utils

Easy management of AWS EC2 instances

## Prerequisites

1. Install `aws` command line utility. Follow the guidelines [
   here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
1. Configure an access to AWS resources.  
   For example, go through `aws configure`

1. Create and populate `~/.ec2_login_opts`.  
   You should specify at least which ssh key to use.  
   `ec2_login_opts.example` will help.

## Usage

1. **Connect** (or resume and connect) to an EC2 instance

   ```bash
   ec2 connect  # using the value of `instance_id` key in '~/.ec2_login_opts'
   ec2 connect 10.111.101.01  # using IP4 (caches also "login and host string" to '/tmp/ec2_$USER-last_login_opts')
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

3. **Sync host folder with its counterpart on the client**

   Imagine you are working on an app that accesses Amazon's Redshift and
   Bedrock services. You configured the access by attaching an appropriate role
   to your EC2 instance. But working on the code and testing it on the EC2 is
   not so convenient. In this case, you can continue work on your workstation
   and just sync and run tests remotely.

   ```bash
   ec2 sync ~/aws-utils '~/aws-utils'  # update host files tracked by git with respective new ones on the client
   ec2 sync -a ~/aws-utils '~/aws-utils'  # update all host files, not just those tracked by git
   ec2 sync -n ~/aws-utils '~/aws-utils'  # do not update anything, just print what will be updated
   ec2 sync -e="bash run_some_tests.sh" ~/aws-utils '~/aws-utils'  # run a command after sync
   ec2 sync --client-always-right ~/aws-utils '~/aws-utils'  # Update with client files even if they are older
   ```

4. **Forward ports** (Por favor)

   ```bash
   ec2 porfowar  # default port is 6006
   PORT=8080 ec2 porfowar
   ```

5. **Shutdown from the client**  
   Clears `$TMP_LOGIN_OPTS` and shuts down the instance.  
   If `$TMP_LOGIN_OPTS` does not exist, will use `instance_id` from `$HOME_LOGIN_OPTS`

   ```bash
   ec2 dicsconnect
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
   If executing within the git-folder then it is `$PWD`.

3. Custom installation by linking to another place that's on the `$PATH`.
   For example, if someone prefers to keep executables in `$HOME/.local/bin`:

   ```bash
   git clone https://github.com/lukoshkin/aws-utils.git
   ln -s "$(readlink -f ec2.sh)" $HOME/.local/bin/ec2
   ```

## Configuration

Improve your user experience with `~/.ec2_login_opts`.  
Check the example [`ec2_login_opts.example`](./ec2_login_opts.example)

- `instance_id` - static id of the EC2 instance  
   It allows to fetch IP4 address without explicitly specifying it in the command
- `sshkey` - path to your key pair used for connecting to the machine
- `workdir` - the directory you get in after ssh login (scope: `ec2 connect`)
- `overwrite_in_tmp` - whether to overwrite destination file if it is in /tmp folder (scope: `ec2 scp-file`)
- `idle_on_first_login` - extra sleep time on the first login after resuming the machine
- `scp_default_dst` - scp's default destination folder (scope: `ec2 scp-file`)  
   If not specified, defaults to `$src`

## Completions

After having installed `ec2`, one can install also shell completions

```bash
ec2 install-completions  # will install for the login shell
```

Or to install to a specific shellrc file (either zhsrc, bashrc or `~/.bash_profile.sh`)

```bash
ec2 install-completions shellrc_file
```

## TODO

- [x] Add README
- [x] Add `ec2` executable
- [x] Add installation
- [x] Add customization of defaults in `~/.ec2_login_opts`
- [x] Add `disconnect` subcommand  
       (unlike `sudo shutdown -h now` on the host, it should also manage  
       clearing the cached values in `/tmp/ec2_$USER-last_login_opts`)
- [x] Add bash/zsh completions for ec2
- [ ] Manage more than one EC2 instance
- [ ] Rename/move/migrate to "aws-cli-utils"?
