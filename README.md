# Build ISO scripts

## Prereqs

Install tool dependencies by running:

```
sudo ./bootstrap
```

This will install the needed RPMs, pkg repos, and Python modules.

## Building the ISO

You need to have a working CentOS 7 ISO, I think any will do. Currently,
the script doesn't do any smart caching, simply downloads all needed RPMs
using yum. If you're tight on bandwidth, you might setup a caching proxy
server.

Run the `master_iso.sh` script and give it the path to your
source ISO, then there are a few optional flags. path you want the output iso to go. long name of a gpg key you want to use in signing. The passphrase for the GPG key. The path to your gpg key if you haven't already imported it. Note that this script does not require root privileges, but your user account does need to be in the `mock`
group to run that tool.

Example:
```
sudo ./master_iso.sh -s ./CentOS-7-x86_64-Everything-1511.iso -o rocknsm-20161101.iso
```

## Creating an offline cache for ROCK NSM

The `offline-snapshot.yml` script allows you to generate an offline snapshot. This
tool is used during the ISO creation, but it is also useful for creating a yum
repository so that you can update offline sensor packages. It can be run with or with out a gpg key. The option SKIP_GPG needs to be set to faulse if want to use your own gpg key and you will need a gpg key already setup and imported into RPM to be used. If haven't you can do
the following otherwise skip these steps.

#### Importing gpg Key
Generate a key. Fill in the information prompted for
```
gpg --gen-key
```

obtain the name of the key from this command
```
gpg --list-keys
```

then export it into a file
```
gpg --export -a 'KEY NAME HERE' > RPM-GPG-KEY-RockNSM
```

Then import it into rpm (NOTE: This step will be completed if you are running the master-iso.sh script. but not in the offline snapshot)
```
sudo rpm --import RPM-GPG-KEY-RockNSM
```

#### Tell ansible about your key
before running ansible you will need to modify a few lines so that it can use
your gpg key. In the `ansible/host_vars/gpg.yml` file. the 3 key points to take away
from this is that you should set the passphrase, name of your key, and any
macro's that you want to pass to ansible.

From my experiance you need at least the following macros
```
_gpg_check_password_cmd: /bin/true
  _signature: gpg
  __gpg: /usr/bin/gpg
  _gpg_path: /home/admin/.gnupg
  _gpg_name: ROCKNSM 2 Key (ROCKNSM 2 Official Signing Key) <security@rocknsm.io>
```

Both the ansible `gpg_key_name` and the gpg macro `gpg_name` must use the long name of the key.
Example, `ROCKNSM 2 Key (ROCKNSM 2 Official Signing Key) <security@rocknsm.io>`

simply run the following command to have ansible run the playbook
```
ansible-playbook offline-snapshot.yml --connection=local
```


## Adding packages to the ISO or the offline-snapshot

If you would like some additional packages for your custom ISO or offline-snapshot
repo, you can add packages by name or groups (using '@' syntax), one per line in the file ansible/roles/common/vars/main.yml.  

This will not install them by default, but they will exist in the repository for installation
in an offline environment.
