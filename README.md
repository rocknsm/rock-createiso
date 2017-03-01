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
source ISO, then optionally the the output filename. Note that this script does 
not require root privileges, but your user account does need to be in the `mock`
group to run that tool.

Example:
```
sudo ./master_iso.sh ./CentOS-7-x86_64-Everything-1511.iso rocknsm-20161101.iso
```

## Creating an offline cache for ROCK NSM

The `offline-snapshot.sh` script allows you to generate an offline snapshot. This
tool is used during the ISO creation, but it is also useful for creating a yum 
repository so that you can update offline sensor packages. To run it, simply run

```
./offline-snapshot.sh [/optional/path/to/dir]
```

If you specify a path, it will create the file structure there. If not, it will
default to `rock_cache` in the current directory of the script.

## Adding packages to the ISO or the offline-snapshot

If you would like some additional packages for your custom ISO or offline-snapshot
repo, you can add packages by name or groups (using '@' syntax), one per line. This
will not install them by default, but they will exist in the repository for installation
in an offline environment.
