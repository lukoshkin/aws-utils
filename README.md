# AWS CLI Utils

Easy management of AWS EC2 instances

_With the proper configuration, one can login, download/upload, forward ports,  
and execute commands remotely with a minor adjustment_

## Prerequisites

1. Install `aws` command line utility. Follow the guidelines [
   here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
1. Configure an access to AWS resources.  
   For example, go through `aws configure`

1. Download the key pairs of your EC2 instances in `~/.ssh/` folder.  
   One can optionally pre-populate the `main.cfg` file with some of the
   defaults at<br>the bottom of `main.cfg.example`.

## Usage

0. Set up the connection to an EC2 instance

   ```bash
   ec2 add i-<instance_id_1> /path/to/corresponding/key1.pem
   ec2 add i-<instance_id_2> /path/to/corresponding/key2.pem
   ec2 init
   ```

   More about the setup process in the help message: `ec2 add -h`.  
   Almost any subcommand has a help message, just add `-h` to it.

1. **Connect** (or resume it and connect) to an EC2 instance

   ```bash
   ec2 pick 2  # Make the second instance the default one
   ec2 connect  # Connect to the default instance
   # or
   ec2 connect --pick  # select the instance interactively before connecting
   ## (same as `ec2 pick` + `ec2 connect`)
   # or
   ec2 connect -p=2
   ```

   Note that the order in `ec2 pick` may differ from the order of adding instances.

2. **Transfer files**

   ```bash
   ec2 scp-file '~/table.csv' /tmp  # download /home/ubuntu/table.csv from the host
   ec2 scp-file -u ~/new-table.csv /tmp  # upload $HOME/new-table.csv to host's /tmp
   UPLOAD= ec2 scp-file ~/new-table.csv /tmp  # The same as the previous command but using the old syntax
   ec2 scp-file -tz '~/datadir' . # download by tarring (`-t` - required for a folder) and compressing (`-z`) the folder
   ```

   One can configure default destination paths for uploads and downloads by editing `main.cfg`.

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

4. After resuming an EC2 instance and picking the default one, commands
   execution is available

   ```bash
   ec2 execute ls  # Single-word command
   ec2 execute 'ls -l'  # Command with arguments
   ec2 execute "$(cat <<EOF
     <command_1>
     ...
     <command_N>
   EOF
   )"  # Multi-line command or several commands execution
   ec2 execute "bash -s" < script.sh  # Execution from a script
   ```

5. **Forward ports** (Por favor)

   ```bash
   ec2 porforwar -P 5000 -P 3000 -P 9000  # Forwarding -L 5000:localhost:5000 -L 8000:localhost:8000 -L 9000:localhost:9000
   ec2 porforwar -P 5000 -P 9090 -H :app:R  # Forwarding -R localhost:5000:app:5000 -L 9090:localhost:9090
   ```

6. **Advanced settings for login and enhanced `connect` functionality**

   ```bash
   ec2 connect -s  # If connected previously, `-s` allows to skip some checks and save time
   ec2 connect -d  # Connect but do not start an interactive session (useful to run other commands: scp-file, sync, ...)
   ec2 connect -d --ip 0.0.0.0/0 --revoke-time 300  # Establish the connection with SSH inbound rule set for any IP for 5 minutes
   ## After 5 minutes, the '0.0.0.0/0' SSH inbound rule will be revoked.

   ec2 connect -w ~/my_project_folder -e 'docker compose up -d'  # Set the working directory and run a command on the login
   ec2 connect -c -w ~/my_project_folder -e 'docker compose up -d'  # Same as the one above + cache the settings
   ec2 connect -p=3 -cc  # Connect to the third instance and remember the choice
   ```

7. **Shutdown from the client**  
   Clears `$TMP_LOGIN_OPTS` and shuts down the instance.  
   If `$TMP_LOGIN_OPTS` does not exist, will use `instance_id` from `$HOME_LOGIN_OPTS`

   ```bash
   ec2 dicsconnect
   ec2 disconnect -p=1,2  # Shutdown the first and the second instances
   ```

8. **Other commands**

   ```bash
   ec2 ls  # List available connections and their statuses/states
   ec2 clean-up  # Remove added SSH inbound rules
   ec2 home  # Show the path to the ec2 folder
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

Improve the user experience with `main.cfg` and `ec2_login_opts/`.  
Check the example [`main.cfg.example`](./main.cfg.example)

Adjustable from config files in `ec2_login_opts/`:

- `user` - user under which to login on the remote host
- `instance_id` - static id of the EC2 instance  
   It allows to fetch IP4 address without explicitly specifying it in the command
- `sshkey` - path to your key pair used for connecting to the machine
- `workdir` - the directory you get in after ssh login (scope: `ec2 connect`)
- `sync_command` - the command to execute on the host each time after `sync`
- `entrypoint` - the command to execute on the host on each login.

To be used in `main.cfg`:

- `overwrite_in_tmp` - whether to overwrite destination file if it is in /tmp folder (scope: `ec2 scp-file`)
- `idle_on_first_login` - extra sleep time on the first login after resuming the machine
- `scp_default_dst` - scp's default destination folder (scope: `ec2 scp-file`)  
   If not specified, defaults to `$src`

### Small nuances

- **Custom path to the configuration file**  
  Modifying the configuration file path is possible with the environment variable `EC2_LOGIN_CFG_PATH`.  
  Setting it in one of the following will work:
  `~/.bashrc`, `~/.bash_profile`, `$ZDOTDIR/.zshrc`, `~/.zshenv`

- **Login under a user other than default**  
  To be able to login under another username, you need to copy (just once) the
  `.ssh` directory of the default user (`ubuntu`) to the home directory of the
  target user on the remote host.

  ```bash
  ## Adding a user 'foreign' for the default connection/instance
  ec2 set-up-user foreign

  ## Does under the hood something like
  # ec2 connect
  # adduser foreign
  # sudo cp -r ~/.ssh /home/foreign
  # sudo chown -R foreign:foreign /home/foreign/.ssh

  ## After adding "user: foreign" to your configuration file (~/ec2_login_opts/<cfg_file>)
  ec2 connect -u foreign
  ## Now you are logged in as "foreign"
  ```

## Completions

After having installed `ec2`, one can install also shell completions

```bash
ec2 install-completions  # will install for the login shell
```

Or to install to a specific shellrc file (either zhsrc, bashrc or `~/.bash_profile.sh`)

```bash
ec2 install-completions <shellrc_file>
```

## TODO

- [x] Add README
- [x] Add `ec2` executable
- [x] Add installation
- [x] Add customization of defaults in `main.cfg`
- [x] Add `disconnect` subcommand  
       (unlike `sudo shutdown -h now` on the host, it should also manage  
       clearing the cached values in `/tmp/ec2_$USER-last_login_opts`)
- [x] Add bash/zsh completions for ec2
- [x] Manage more than one EC2 instance
- [x] Rewrite to use a separate config for each instance
- [x] Update README after finishing multi-instance management feature
- [x] Automate configuration of non-default (not 'ubuntu') user
- [ ] Add a GIF with a demo
- [ ] Rename/move/migrate to "aws-cli-utils"?
