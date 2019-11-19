# app-hpctest
HPC Test Bench based on CentOS 7 with the [Slurm] job scheduler and [OpenMPI] message passing interface (MPI)
for validating and benchmarking HPC workflows on the [Nimbix Cloud]

Slurm is built from source, no RPM is available upstream, in a multistage build. 

OpenMPI 3 is installed from EPEL

### systemd limits
https://wiki.fysik.dtu.dk/niflheim/Slurm_configuration#slurmd-systemd-limits

[Slurm]: https://slurm.schedmd.com/

[OpenMPI]: https://www.open-mpi.org/

[Nimbix Cloud]: https://www.nimbix.net/platform/