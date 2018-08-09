#!/usr/bin/python

from __future__ import absolute_import, division, print_function

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['stableinterface'],
                    'supported_by': 'community'}


DOCUMENTATION = '''
---
version_added: "0.0"
module: repodownloader
short_description: Build repo dep tree and download all required rpms
description:
   - Build repo dep tree and download required rpms
options:
  config:
    description:
      - config file to use (default: /etc/yum.conf)
    required: false
    default: "/etc/yum.conf"
  arch:
    description:
      - check as if running the specified arch (default: current arch)
    required: false
    default: null
  repoid:
    description:
      - Specify repo ids to query, can be specified multiple times (default: all)
    required: false
    default: []
  tempcache:
    description:
      - Use a temp dir for storing/accessing yum-cache (default: false)
    required: false
    default: false
  download_path:
    description:
      - Path to download packages to (default: /tmp/repodownload)
    required: false
    default: /tmp/repodownload
  urls:
    description:
      - Just list urls of what would be downloaded, don't download (default: false)
    required: false
    default: false
  newest:
    description:
      - Toggle downloading only the newest packages (default: true)
    required: false
    default: true
  exclude
    description:
      - Exclude package or partial string match just prior to downloading (default: null)
    required: false
    default: null
  groups
    description
      - Groups to query in addition to supplied packages (default: [])
    required: false
    default: []
  packages:
    description
      - List of packages to download (default: [])
    required: false
    default: []

# informational: requirements for nodes
requirements:
    - yum
    - rpmUtils
author: "Johnathon Hall"
'''

EXAMPLES = '''
# Download packages
- repodownloader:
    packages:
      - bro
      - suricata

# Download packages from a group and using a config file
- repodownloader:
    packages:
      -  bro
      -  suricata
    groups:
      - core
      - anaconda-tools
    config: "/tmp/myconfig.conf"
# Download packages both specified and from a group while excluding a pattern
- repodownloader:
    packages:
      -  bro
      -  suricata
    groups:
      - core
      - anaconda-tools
    config: "/tmp/myconfig.conf"
    download_path: "/tmp/mypackages/"
    exclude: "i686"
'''

import os
import sys
import shutil
from urlparse import urljoin

import fnmatch

try:
    import yum
    HAS_YUM = True
except ImportError:
    HAS_YUM = False

try:
    import yum.Errors
    from yum.misc import getCacheDir
    from yum.constants import *
    from yum.packages import parsePackages
    from yum.packageSack import ListPackageSack
    from yum.i18n import to_unicode
    import rpmUtils
    TRANSACTION_HELPERS = True
except ImportError:
    TRANSACTION_HELPERS = False

from ansible.module_utils.basic import AnsibleModule

class groupQuery:
    def __init__(self, group, grouppkgs="required"):
        self.grouppkgs = grouppkgs
        self.id = group.groupid
        self.name = group.name
        self.group = group

    def doQuery(self, method, *args, **kw):
        if hasattr(self, "fmt_%s" % method):
            return "\n".join(getattr(self, "fmt_%s" % method)(*args, **kw))
        else:
            raise queryError("Invalid group query: %s" % method)

    # XXX temporary hack to make --group -a query work
    def fmt_queryformat(self, **kw):
        return self.fmt_nevra()

    def fmt_nevra(self, **kw):
        return ["%s - %s" % (self.id, self.name)]

    def fmt_list(self, **kw):
        pkgs = []
        for t in self.grouppkgs.split(','):
            if t == "mandatory":
                pkgs.extend(self.group.mandatory_packages)
            elif t == "default":
                pkgs.extend(self.group.default_packages)
            elif t == "optional":
                pkgs.extend(self.group.optional_packages)
            elif t == "all":
                pkgs.extend(self.group.packages)
            else:
                raise queryError("Unknown group package type %s" % t)

        return pkgs

    def fmt_requires(self, **kw):
        return self.group.mandatory_packages

    def fmt_info(self, **kw):
        return ["%s:\n\n%s\n" % (self.name, self.group.description)]


class queryError(Exception):
    def __init__(self, value=None):
        Exception.__init__(self)
        self.value = value
    def __str__(self):
        return "%s" %(self.value,)

    def __unicode__(self):
        return '%s' % to_unicode(self.value)


class RepoTrack(yum.YumBase):
    def __init__(self, opts):
        yum.YumBase.__init__(self)
        self.opts = opts

    def findDeps(self, po):
        """Return the dependencies for a given package, as well
           possible solutions for those dependencies.
           Returns the deps as a dict  of:
            dict[reqs] = [list of satisfying pkgs]"""


        reqs = po.returnPrco('requires')
        reqs.sort()
        pkgresults = {}

        for req in reqs:
            (r,f,v) = req
            if r.startswith('rpmlib('):
                continue

            pkgresults[req] = list(self.whatProvides(r, f, v))

        return pkgresults

    def returnGroups(self):
        grps = []
        for group in self.comps.get_groups():
            grp = groupQuery(group, grouppkgs = "all")
            grps.append(grp)
        return grps

    def matchGroups(self, items):
        grps = []
        for grp in self.returnGroups():
            for expr in items:
                if grp.name == expr or fnmatch.fnmatch("%s" % grp.name, expr):
                    grps.append(grp)
                elif grp.id == expr or fnmatch.fnmatch("%s" % grp.id, expr):
                    grps.append(grp)

        return grps


def more_to_check(unprocessed_pkgs):
    for pkg in unprocessed_pkgs.keys():
        if unprocessed_pkgs[pkg] is not None:
            return True

    return False


def main():

    module = AnsibleModule(
        argument_spec=dict(
            config=dict(type='str', required=False, default="/etc/yum.conf"),
            arch=dict(type='str', required=False, default=None),
            repoid=dict(type='list', required=False, default=[]),
            tempcache=dict(type='bool', required=False, default=False),
            download_path=dict(type='str', required=False, default="/tmp/repodownload"),
            urls=dict(type='bool', required=False, default=False),
            exclude=dict(type='str', required=False, default=None),
            groups=dict(type='list', required=False, default=[]),
            packages=dict(type='list', required=False, default=[]),
            # present==latest this is an alias
            state=dict(type='str', required=False, default='latest', choices=['present', 'latest', 'all'])
        ),
        supports_check_mode=True
    )

    if not TRANSACTION_HELPERS:
        module.fail_json(rc=1, msg='Error: python2 rpmUtils module is needed for this module')

    if not HAS_YUM:
        module.fail_json(rc=1, msg='Error: python2 yum module is needed for this module')

    #default to only pulling newest packages
    newest = True
    if module.params["state"] == 'all':
        newest = False

    if len(module.params["packages"]) == 0 and not module.params["groups"]:
        module.fail_json(rc=1, msg='Error: no packages or groups specified')

    if not os.path.exists(module.params["download_path"]) and not module.params["urls"]:
        try:
            os.makedirs(module.params["download_path"])
        except OSError, e:
            module.fail_json(rc=1, msg='Error: Cannot create destination dir {}'
                                       ''.format(module.params["download_path"]))

    if not os.access(module.params["download_path"], os.W_OK) and not module.params["urls"]:
        module.fail_json(rc=1, msg='Error: Cannot write to destination dir {}'
                                   ''.format(module.params["download_path"]))


    my = RepoTrack(opts=module.params)
    my.doConfigSetup(fn=module.params["config"], init_plugins=False) # init yum, without plugins

    if module.params["arch"]:
        archlist = []
        archlist.extend(rpmUtils.arch.getArchList(module.params["arch"]))
    else:
        archlist = rpmUtils.arch.getArchList()

    # do the happy tmpdir thing if we're not root
    if os.geteuid() != 0 or module.params["tempcache"]:
        cachedir = getCacheDir()
        if cachedir is None:
            module.fail_json(rc=1, msg='Error: Could not make cachedir')
        my.repos.setCacheDir(cachedir)

    if module.params["groups"]:
        my.doGroupSetup()
    user_pkgs = module.params["packages"]
    pkgs = my.matchGroups(module.params["groups"])
    for pkg in pkgs:
        tmp = pkg.fmt_list()
        user_pkgs += tmp

    if len(module.params["repoid"]) > 0:
        myrepos = []

        # find the ones we want
        for glob in module.params["repoid"]:
            myrepos.extend(my.repos.findRepos(glob))

        # disable them all
        for repo in my.repos.repos.values():
            repo.disable()

        # enable the ones we like
        for repo in myrepos:
            repo.enable()
            my._getSacks(archlist=archlist, thisrepo=repo.id)

    my.doRepoSetup()
    my._getSacks(archlist=archlist)

    unprocessed_pkgs = {}
    final_pkgs = {}
    pkg_list = []
    results = {
        "changed": False,
        "results": [],
        "changes": []
    }


    avail = my.pkgSack.returnPackages()
    for item in user_pkgs:
        exactmatch, matched, unmatched = parsePackages(avail, [item])
        pkg_list.extend(exactmatch)
        pkg_list.extend(matched)
        if newest:
            this_sack = ListPackageSack()
            this_sack.addList(pkg_list)
            pkg_list = this_sack.returnNewestByNameArch()
            del this_sack

    if len(pkg_list) == 0:
        module.fail_json(rc=1, msg='Nothing found to download matching packages/groups specified')

    for po in pkg_list:
        unprocessed_pkgs[po.pkgtup] = po


    while more_to_check(unprocessed_pkgs):
        for pkgtup in unprocessed_pkgs.keys():
            if unprocessed_pkgs[pkgtup] is None:
                continue

            po = unprocessed_pkgs[pkgtup]
            final_pkgs[po.pkgtup] = po

            deps_dict = my.findDeps(po)
            unprocessed_pkgs[po.pkgtup] = None
            for req in deps_dict.keys():
                pkg_list = deps_dict[req]
                if newest:
                    this_sack = ListPackageSack()
                    this_sack.addList(pkg_list)
                    pkg_list = this_sack.returnNewestByNameArch()
                    del this_sack

                for res in pkg_list:
                    if res is not None and res.pkgtup not in unprocessed_pkgs:
                        unprocessed_pkgs[res.pkgtup] = res

    if module.params["exclude"]:
        for key, package in final_pkgs.items():
            if module.params["exclude"] in str(package):
                del final_pkgs[key]

    download_list = final_pkgs.values()
    if newest:
        this_sack = ListPackageSack()
        this_sack.addList(download_list)
        download_list = this_sack.returnNewestByNameArch()

    download_list.sort(key=lambda pkg: pkg.name)
    for pkg in download_list:
        repo = my.repos.getRepo(pkg.repoid)
        remote = pkg.returnSimple('relativepath')
        local = os.path.basename(remote)
        local = os.path.join(module.params["download_path"], local)
        if (os.path.exists(local) and
                    os.path.getsize(local) == int(pkg.returnSimple('packagesize'))):
            results['results'].append('{} already exists'.format(local))
            continue

        if module.params["urls"]:
            url = urljoin(repo.urls[0], remote)
            continue

        # Disable cache otherwise things won't download
        repo.cache = 0
        pkg.localpath = local  # Hack: to set the localpath to what we want.
        path = repo.getPackage(pkg)
        results['changes'].append(pkg.name)
        if not results['changed']:
            results['changed'] = True
        results['results'].append('Downloading {}'.format(os.path.basename(remote)))

        if not os.path.exists(local) or not os.path.samefile(path, local):
            shutil.copy2(path, local)

    module.exit_json(changed=results["changed"], results=results['results'], changes=dict(downloaded=results['changes']))

if __name__ == "__main__":
    main()
