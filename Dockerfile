FROM jarvice/base-centos-torque

COPY 01-openmpi-path.sh /etc/profile.d/01-openmpi-path.sh
COPY AppDef.json /etc/NAE/AppDef.json

