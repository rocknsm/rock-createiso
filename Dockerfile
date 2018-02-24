# Copyright 2017, 2018 RockNSM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
FROM fedora:27

MAINTAINER "Derek Ditch" <derek@rocknsm.io>

ENV WORKSPACE=${WORKSPACE} \
    SOURCES=/sources \
    OUTPUT=/output \
    CACHEDIR=/cachedir \
    YUM=yum \
    PACKAGES="python-pip python-jinja2 python-simplejson pykickstart createrepo rsync isomd5sum syslinux pigz mkisofs libguestfs-tools-c initial-setup tree yum-utils rpm-sign" \
    PYTHON_PKGS="pythonpy"
RUN ${YUM} -y install ${PACKAGES} ${EXTRA_PACKAGES} \
    && ${YUM} -y clean all \
    && pip install ${PYTHON_PKGS} \
    && mkdir -p ${SOURCES} ${OUTPUT} ${CACHEDIR}
VOLUME ["${SOURCES}", "${OUTPUT}", "${CACHEDIR}"]
