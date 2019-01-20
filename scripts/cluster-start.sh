#!/usr/bin/env bash
#
# Copyright (c) 2019, Nimbix, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of Nimbix, Inc.
#

# Designate the first host as Slurm controller
# and replace hostname in slurm.conf
read -r CTRLR < /etc/JARVICE/nodes
sudo sed -i "s/ControlMachine=JARVICE/ControlMachine=${CTRLR}/" /etc/slurm/slurm.conf

# Modify slurm.conf for DEFAULT settings if CPUs > 1
#  e.g. NodeName=DEFAULT Procs=1 SocketsPerBoard=2 CoresPerSocket=4 ThreadsPerCore=1
SOCKETSPER=$(lscpu | grep Socket\(s\) | awk '{print $2}')
COREPER=$(lscpu | grep Core\(s\) | awk '{print $4}')
THREADPER=$(lscpu | grep Thread\(s\) | awk '{print $4}')
NUMCPU=$(nproc)
if [[ ${NUMCPU} -gt 1 ]]; then
    echo "  Updating Slurm CPU defaults..."
    sudo sed -i "s/NodeName=DEFAULT Procs=1/NodeName=DEFAULT Procs=${NUMCPU} SocketsPerBoard=${SOCKETSPER} CoresPerSocket=${COREPER} ThreadsPerCore=${THREADPER}/" /etc/slurm/slurm.conf
fi

# Update slurm.conf for node names
#   Add the controller host if there's only one node
if [[ $(wc -l < /etc/JARVICE/nodes) -eq 1 ]] ; then
    sudo echo "NodeName=$HOSTNAME" | sudo tee --append /etc/slurm/slurm.conf > /dev/null
else
    for i in $(grep -v ^$HOSTNAME /etc/JARVICE/nodes); do
        sudo echo "NodeName=$i" | sudo tee --append /etc/slurm/slurm.conf > /dev/null
    done
fi

# Start munged as munge user, using the shared key, before the Slurm daemons
sudo -u munge mkdir /var/run/munge
sudo -u munge munged

# Start controller if on first node and
#   start slurmd if only one node
echo "  Starting Slurm daemons on controller node: $HOSTNAME..."
if [[ $(wc -l < /etc/JARVICE/nodes) -eq 1 ]] ; then
    sudo slurmctld
    sudo slurmd
else
    sudo slurmctld
fi

# Copy the config to the compute nodes and start the services
for i in `grep -v ^$HOSTNAME /etc/JARVICE/nodes`; do
    echo "  Starting munge daemon on compute node $i..."
    ssh ${i} sudo -u munge mkdir /var/run/munge
    ssh ${i} sudo -u munge munged > /dev/null
    echo "  Starting Slurm daemon on compute node $i..."
    scp /etc/slurm/slurm.conf ${i}:/tmp/slurm.conf > /dev/null
    ssh ${i} sudo cp -f /tmp/slurm.conf /etc/slurm/slurm.conf
    ssh ${i} sudo /usr/sbin/slurmd > /dev/null
    ssh ${i} ln -sf /data /home/nimbix
done

# Start the desktop environment
echo "  Starting the desktop environment..."
exec /usr/local/bin/nimbix_desktop
