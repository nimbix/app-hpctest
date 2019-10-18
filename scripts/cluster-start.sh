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

# start SSHd
TOOLSDIR="/usr/local/JARVICE/tools"
sudo service sshd status >/dev/null 2>&1 || sudo service sshd start
sudo service sshd status >/dev/null 2>&1 || ${TOOLSDIR}/bin/sshd_start

# Wait for slaves...max of 60 seconds
SLAVE_CHECK_TIMEOUT=60
${TOOLSDIR}/bin/python_ssh_test ${SLAVE_CHECK_TIMEOUT}
ERR=$?
if [[ ${ERR} -gt 0 ]]; then
    echo "One or more slaves failed to start" 1>&2
    exit ${ERR}
fi

# Designate the first host as Slurm controller
# and replace hostname in slurm.conf
read -r CTRLR < /etc/JARVICE/nodes
sudo sed -i "s/ControlMachine=JARVICE/ControlMachine=${CTRLR}/" /etc/slurm/slurm.conf

# Modify slurm.conf to indicate the general resources if GPUs are present
#   model is Gres=gpu:tesla:2 but drop the optional Type
echo "  Adding Slurm GPU defaults, if present..."
NUMGPU=$( (nvidia-smi -L 2>/dev/null || true)| wc -l )
GPUDEF=""
[[ ${NUMGPU} -gt 0 ]] && GPUDEF="Gres=gpu:${NUMGPU}" && echo "  Detected ${NUMGPU} GPUs..."

# Modify slurm.conf for DEFAULT settings if CPUs > 1
#  e.g. NodeName=DEFAULT Procs=1 SocketsPerBoard=2 CoresPerSocket=4 ThreadsPerCore=1
SOCKETSPER=$(lscpu | grep Socket\(s\) | awk '{print $2}')
COREPER=$(lscpu | grep Core\(s\) | awk '{print $4}')
THREADPER=$(lscpu | grep Thread\(s\) | awk '{print $4}')
NUMCPU=$(lscpu | grep ^CPU\(s\) | awk '{print $2}')

if [[ ${NUMCPU} -gt 1 ]]; then
    echo "  Updating Slurm CPU defaults..."
    CPUDEF="Procs=${NUMCPU} SocketsPerBoard=${SOCKETSPER} CoresPerSocket=${COREPER} ThreadsPerCore=${THREADPER} RealMemory=10000"
    sudo sed -i "s/NodeName=DEFAULT Procs=1/NodeName=DEFAULT ${CPUDEF} ${GPUDEF}/" /etc/slurm/slurm.conf
fi

# Update slurm.conf for compute node names
#   Add the controller host as a compute node as well
echo "  Adding compute nodes to config..."
while read -r node
do
  sudo echo "NodeName=$node" | sudo tee --append /etc/slurm/slurm.conf > /dev/null
done <  /etc/JARVICE/nodes

# Update the gres.conf if GPUs are present
if [[ ${NUMGPU} -eq 1 ]]; then
    echo "  Adding single GPU device to resource config..."
    sudo echo "Name=gpu File=/dev/nvidia0" | sudo tee --append /etc/slurm/gres.conf > /dev/null
elif [[ ${NUMGPU} -gt 1 ]]; then
    IDXGPU=$(expr ${NUMGPU} - 1)
    echo "  Adding GPU devices to resource config..."
    sudo echo "Name=gpu File=/dev/nvidia[0-${IDXGPU}]" | sudo tee --append /etc/slurm/gres.conf > /dev/null
fi

# Start munged as munge user, using the shared key, before the Slurm daemons
echo "  Starting Munge daemon on controller node..."
sudo -u munge mkdir /var/run/munge
sudo -u munge munged

# Start controller if on first node and
#   start slurmd as well
echo "  Starting Slurm daemons on controller node: $HOSTNAME..."
sudo slurmctld
sudo slurmd

# Copy the configs to the compute nodes and start the services
for i in $(grep -v "^$HOSTNAME" /etc/JARVICE/nodes); do
    echo "  Starting munge daemon on compute node $i..."
    ssh ${i} sudo -u munge mkdir /var/run/munge
    ssh ${i} sudo -u munge munged > /dev/null

    echo "  Starting Slurm daemon on compute node $i..."
    scp /etc/slurm/slurm.conf ${i}:/tmp/slurm.conf > /dev/null
    scp /etc/slurm/gres.conf ${i}:/tmp/gres.conf > /dev/null
    ssh ${i} sudo cp -f /tmp/slurm.conf /etc/slurm/slurm.conf
    ssh ${i} sudo cp -f /tmp/gres.conf /etc/slurm/gres.conf
    ssh ${i} sudo /usr/sbin/slurmd > /dev/null
    ssh ${i} ln -sf /data $HOME
done

# Start the desktop environment
echo "  Starting the desktop environment..."
echo
echo
exec /usr/local/bin/nimbix_desktop
