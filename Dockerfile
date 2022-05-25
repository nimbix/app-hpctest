# Slurm release
ARG SLURM_VER=18.08.8

################# Multistage Build, stage 1 ###################################
FROM centos:7 AS build
LABEL maintainer="Nimbix, Inc." \
      license="BSD"

# Update SERIAL_NUMBER to force rebuild of all layers (don't use cached layers)
ARG SERIAL_NUMBER
ENV SERIAL_NUMBER ${SERIAL_NUMBER:-20191201.1200}

ARG SLURM_VER

WORKDIR /tmp

# Download and build the Slurm RPMs for install in next stage
# Add build tools
# Add EPEL to pick up build dependencies
RUN yum -y groupinstall "Development Tools" && \
    yum -y install epel-release && \
    yum -y install wget munge-devel munge-libs readline-devel mariadb-devel \
    openssl-devel openssl perl-ExtUtils-MakeMaker pam-devel bzip2 \
    openmpi3-devel openssl openssl-devel libssh2-devel pam-devel numactl \
    numactl-devel hwloc hwloc-devel lua lua-devel readline-devel ncurses-devel \
    gtk2-devel man2html libibmad libibumad perl-Switch

RUN wget "https://github.com/SchedMD/slurm/archive/refs/tags/slurm-${SLURM_VER//./-}-1.tar.gz" && \
    tar -xf "slurm-${SLURM_VER//./-}-1.tar.gz" && \
    mv "slurm-slurm-${SLURM_VER//./-}-1" "slurm-${SLURM_VER}" && \
    tar -cf "slurm-${SLURM_VER}.tar" "slurm-${SLURM_VER}" && \
    bzip2 "slurm-${SLURM_VER}.tar" && \
    rpmbuild -ta --with mysql slurm-${SLURM_VER}.tar.bz2 --define "_rpmdir /tmp"

################# Multistage Build, stage 2 ###################################
#FROM nvidia/cuda:8.0-devel-centos7
FROM nvidia/cuda@sha256:6b69a95461c475611c35c498df59ef39e0da8416786acdf0c859472fb71590d2
LABEL maintainer="Nimbix, Inc." \
      license="BSD"

# Update SERIAL_NUMBER to force rebuild of all layers (don't use cached layers)
ARG SERIAL_NUMBER
ENV SERIAL_NUMBER ${SERIAL_NUMBER:-20191203.1000}

ARG SLURM_VER

# Copy the built RPMs from the last stage, saving image size w/o built tools
COPY --from=build /tmp/x86_64/*.rpm /tmp/slurm/

# Install runtime libs and handy tools, lock repo to 7.6 for MPI compatibility
RUN sed -e  "s/7.5.1804/7.6.1810/g"  -i /etc/yum.repos.d/CentOS-Vault.repo && \
    yum -y install epel-release python36 && \
    yum-config-manager --enable C7.6.1810-base && \
    yum-config-manager --enable C7.6.1810-updates && \
    yum-config-manager --disable base && \
    yum-config-manager --disable updates && \
    curl -H 'Cache-Control: no-cache' \
    https://raw.githubusercontent.com/nimbix/image-common/master/install-nimbix.sh \
    | bash -s -- --setup-nimbix-desktop --image-common-branch centos7 && \
    yum -y install nano vim emacs man openmpi3 openmpi3-devel munge munge-libs \
                   mariadb-libs && \
    yum -y install /tmp/slurm/slurm-${SLURM_VER}*.rpm \
                   /tmp/slurm/slurm-slurmctld*.rpm \
                   /tmp/slurm/slurm-slurmd-*.rpm \
                   /tmp/slurm/slurm-libpmi-*.rpm && \
    yum clean all

# Spool dirs for the controller
RUN mkdir -p /var/spool/slurm/ctld /var/spool/slurm/d

# plant a static munge key so all nodes are in sync
WORKDIR /etc/munge
COPY --chown=munge:munge etc/munge.key .
RUN chmod 0400 /etc/munge/munge.key

# Configuration scripts for each node
COPY etc/slurm.conf /etc/slurm/slurm.conf
COPY etc/gres.conf /etc/slurm/gres.conf
COPY etc/openmpi-path.sh /etc/profile.d/openmpi-path.sh

# /usr/bin/ping fixup
RUN chmod 04555 /usr/bin/ping

# Install helper scripts for the running environment
WORKDIR /usr/local/scripts
COPY scripts/cluster-start.sh .

# Add the Nimbix tools
RUN mkdir -p /etc/NAE && touch /etc/NAE/screenshot.png /etc/NAE/screenshot.txt /etc/NAE/license.txt /etc/NAE/AppDef.json
COPY NAE/AppDef.json /etc/NAE/AppDef.json
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://cloud.nimbix.net/api/jarvice/validate
