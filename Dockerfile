FROM jarvice/base-centos-torque:6.0.4

RUN yum -y install nano vim emacs man && yum clean all
COPY 01-openmpi-path.sh /etc/profile.d/01-openmpi-path.sh
COPY AppDef.json /etc/NAE/AppDef.json

