# Container Storage Setup

## Tool for setting up container runtimes storage

`container-storage-setup` is part of the [Project Atomic](http://www.projectatomic.io/) suite of container projects, formerly known as docker-storage-setup.


A crucial aspect to container runtimes is the concept of the copy-on-write (COW) layered filesystems.  The [Docker Engine Storage docs](https://docs.docker.com/engine/userguide/storagedriver/) site explains how the docker daemon uses uses COW file systems

`container-storage-setup` is a script to configure COW File systems like devicemapper and overlayfs.   It is usually run via a systemd service.  For example `docker-storage-setup.service`, runs `container-storage-setup` before the docker.service script starts the docker daemon.

The `container-storage-service` script takes an input file and an output file as parameters.  The input file is usually provided by the distribution and
is expected to be modified by administrators. The script generates the specified output file as a configuration file bash script which sets environment variables to be used by the container runtime service script.

For example if I configured an runtime-storage-setup to look like

```
cat /etc/sysconfig/runtime-storage-setup 
STORAGE_DRIVER="overlay2"
```

If I then executed

```
container-storage-setup /etc/sysconfig/runtime-storage-setup  /etc/sysconfig/runtime-storage
```

I will end up with a runtime storage file which looks like.

```
cat /etc/sysconfig/runtime-storage
STORAGE_OPTIONS="--storage-driver overlay2 "
```

The service script of the container runtime should have something like

```
EnvironmentFile=-/etc/sysconfig/runtime-storage
...
ExecStart=/usr/bin/container-runtime $STORAGE_OPTIONS
...
```

Obviously the container runtime must handle the --storage-driver option.

NOTE: `container-storage-setup` has legacy support for docker-storage-setup.  If you execute the script without specifying an input file and and output file, it will default to an input file of `/etc/sysconfig/docker-storage-setup` and an output file of `/etc/sysconfig/docker-storage`.  The Environment name in the output file will be set to DOCKER_STORAGE_OPTIONS.

```
cat /etc/sysconfig/docker-storage-setup 
STORAGE_DRIVER="overlay2"
```

If I then executed

```
container-storage-setup
```

I will end up with a runtime storage file which looks like.

```
cat /etc/sysconfig/docker-storage
DOCKER_STORAGE_OPTIONS="--storage-driver overlay2 "
```

#### Input File 

The input file should be setup by distributions or by the packagers of the
container runtimes.  The contents can also be set during system
bootstrap, e.g. in a `cloud-init` `bootcmd:` hook, or via
kickstart `%post`.


For more information on configuration, see
[man container-storage-setup](container-storage-setup.1).
