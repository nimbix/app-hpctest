#!/usr/bin/env bash

# source the job info

# set hostname to match slurm.conf

# sed slurm.conf for node names, DEFAULT settings for #CPUs


# start munge as munge user, needs key
sudo -u munge munged

sudo slurmctld

sudo slurmd

# TODO: temp
xfce4-terminal
