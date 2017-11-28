FROM fedora:27

MAINTAINER "Derek Ditch" <derek@rocknsm.io>

ENV WORKSPACE=${WORKSPACE} \
    SOURCES=/sources \
    OUTPUT=/output \
    CACHEDIR=/cachedir \
    YUM=yum \
    PACKAGES="python-pip python-jinja2 python-simplejson pykickstart createrepo rsync isomd5sum syslinux pigz mkisofs libguestfs-tools-c initial-setup tree" \
    PYTHON_PKGS="pythonpy"
RUN ${YUM} -y install ${PACKAGES} ${EXTRA_PACKAGES} \
    && ${YUM} -y clean all \
    && pip install ${PYTHON_PKGS} \
    && mkdir -p ${SOURCES} ${OUTPUT} ${CACHEDIR}
VOLUME ["${SOURCES}", "${OUTPUT}", "${CACHEDIR}"]


