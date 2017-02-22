container-storage-setup
====================

A crucial aspect to container runtimes is the concept of the copy-on-write layered
filesystems.  There is a significant amount of documentation on this upstream:

[Docker Engine Storage docs](https://docs.docker.com/engine/userguide/storagedriver/)

`container-storage-setup` is a script to configure the devicemapper or
overlayfs backends, part of the
[Project Atomic](http://www.projectatomic.io/) suite of container
projects.  It is usually run via a systemd service, like
`docker-storage-setup.service`, before the Container runtime daemons. This
script and service then ensures storage is provisioned according to
configuration in environment files, `/etc/sysconfig/docker-storage-setup`.

You should typically set the contents of that file during system
bootstrap, e.g. in a `cloud-init` `bootcmd:` hook, or via
kickstart `%post`.

Also, in a cloud (OpenStack/AWS/etc.) scenario with the devicemapper
backend, `container-storage-setup` can also expand the root volume group
to fill the space allocated for the root disk if `GROWPART=true` is
set.

For more information on configuration, see
[man container-storage-setup](container-storage-setup.1).
