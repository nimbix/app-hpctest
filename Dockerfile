FROM jarvice/base-centos-torque:6.0.4

COPY 01-openmpi-path.sh /etc/profile.d/01-openmpi-path.sh
COPY AppDef.json /etc/NAE/AppDef.json

