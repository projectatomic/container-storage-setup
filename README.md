docker-storage-setup
====================

A crucial aspect to Docker is the concept of the copy-on-write layered
filesystems.  There is a significant amount of documentation on this upstream:

[Docker Engine Storage docs](https://docs.docker.com/engine/userguide/storagedriver/)

`docker-storage-setup` is a script to configure the devicemapper or
overlayfs backends, part of the
[Project Atomic](http://www.projectatomic.io/) suite of container
projects.  It is run via a systemd service
`docker-storage-setup.service` before the Docker daemon, ensuring
storage is provisioned according to configuration in
`/etc/sysconfig/docker-storage-setup`.

You should typically set the contents of that file during system
bootstrap, e.g. in a `cloud-init` `bootcmd:` hook, or via
kickstart `%post`.

Also, in a cloud (OpenStack/AWS/etc.) scenario with the devicemapper
backend, `docker-storage-setup` can also expand the root volume group
to fill the space allocated for the root disk if `GROWPART=true` is
set.

For more information on configuration, see
[man docker-storage-setup](docker-storage-setup.1).
