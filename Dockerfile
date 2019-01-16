# Slurm release
ARG SLURM_VER=18.08.4

################# Multistage Build, stage 1 ###################################
FROM centos:7 AS build
LABEL maintainer="Nimbix, Inc." \
      license="BSD"

# Update SERIAL_NUMBER to force rebuild of all layers (don't use cached layers)
ARG SERIAL_NUMBER
ENV SERIAL_NUMBER ${SERIAL_NUMBER:-20180116.1200}

ARG SLURM_VER

WORKDIR /tmp

# Download and build the Slurm RPMs for install in next stage
# Add build tools
# Add EPEL to pick up build dependencies
RUN curl -O https://download.schedmd.com/slurm/slurm-${SLURM_VER}.tar.bz2 && \
    yum -y groupinstall "Development Tools" && \
    yum -y install epel-release && \
    yum -y install munge-devel munge-libs readline-devel mariadb-devel \
    openssl-devel openssl perl-ExtUtils-MakeMaker pam-devel bzip2 && \
    rpmbuild -ta slurm-${SLURM_VER}.tar.bz2 --define "_rpmdir /tmp"

################# Multistage Build, stage 2 ###################################
FROM centos/systemd:latest
LABEL maintainer="Nimbix, Inc." \
      license="BSD"

# Update SERIAL_NUMBER to force rebuild of all layers (don't use cached layers)
ARG SERIAL_NUMBER
ENV SERIAL_NUMBER ${SERIAL_NUMBER:-20180116.1200}

ARG SLURM_VER

# Copy the built RPMs from the last stage, saving image size w/o built tools
COPY --from=build /tmp/x86_64/*.rpm /tmp/slurm/

# Install runtime libs and handy tools
#RUN yum -y install nano vim emacs man openmpi3 munge munge-libs mariadb-libs && \
#    yum -y localinstall /tmp/slurm/slurm-${SLURM_VER}*.rpm /tmp/slurm/slurm-slurmctld*.rpm && \
#    yum clean all

RUN yum -y install epel-release
RUN curl -H 'Cache-Control: no-cache' \
    https://raw.githubusercontent.com/nimbix/image-common/master/install-nimbix.sh \
    | bash -s -- --setup-nimbix-desktop
RUN yum -y install nano vim emacs man openmpi3 munge munge-libs mariadb-libs
RUN yum -y install /tmp/slurm/slurm-${SLURM_VER}*.rpm /tmp/slurm/slurm-slurmctld*.rpm && \
    yum clean all

# Spool dirs for ctld
RUN mkdir -p /var/spool/slurm/ctld

# Install helper scripts for the running environment
COPY scripts/openmpi-path.sh /etc/profile.d/openmpi-path.sh
COPY scripts/slurm.conf /etc/slurm/slurm.conf

# Add the Nimbix tools
COPY NAE/AppDef.json /etc/NAE/AppDef.json
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://api.jarvice.com/jarvice/validate

# Expose port 22 for local JARVICE emulation in docker
EXPOSE 22

# for standalone use
EXPOSE 5901
EXPOSE 443