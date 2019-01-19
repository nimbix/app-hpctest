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
#  e.g. NodeName=DEFAULT Procs=1
NUMCPU=$(wc -l < /etc/JARVICE/cores)
if [[ ${NUMCPU} -gt 1 ]]; then
    sudo sed -i "s/NodeName=DEFAULT Procs=1/NodeName=DEFAULT Procs=${NUMCPU}" /etc/slurm/slurm.conf
fi

# sed slurm.conf for node names, DEFAULT settings for #CPUs
for i in $(cat /etc/JARVICE/nodes); do
#    sudo echo "NodeName=$i" >> /etc/slurm/slurm.conf
    sudo echo "NodeName=$i" | sudo tee --append /etc/slurm/slurm.conf > /dev/null
done

# Start munged as munge user, using the shared key, before the Slurm daemons
sudo -u munge munged

# Start controller if on first node and
#   start slurmd on all other nodes, unless only one node
if [[ "$HOSTNAME" = ${CTRLR} ]] && [[ $(wc -l < /etc/JARVICE/nodes) -eq 1 ]] ; then
    sudo slurmctld
    sudo slurmd
elif [[ "$HOSTNAME" = ${CTRLR} ]] ; then
    sudo slurmctld
else
    sudo slurmd
fi

# Start the desktop environment
exec /usr/local/bin/nimbix_desktop
