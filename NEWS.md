0.5
---

This release has many changes contributed primarily by Vivek Goyal.

### Docker pool just uses 60%, and will auto-grow using LVM

 - docker-storage-setup: Reserve 60% of free space for data volume
 - docker-storage-setup: Enable automatic pool extension using lvm facilities
 - docker-storage-setup: Do not grow data volumes upon restart

These three changes mean that storage is now more dynamic in a
more reliable fashion.

Previously, the pool would use all configured space, which meant
things like Docker volumes or regular host storage would be limited to
the OS default (for Project Atomic, 3G).  With this change, the root
LV can be grown by the system administrator dynamically.

The growing of the Docker pool is now managed by LVM dynamically, and
will not be automatically resized whenever d-s-s runs (normally once
on boot).

### Growpart logic reworked

In cloud environments, a "growpart" logic is common where the partition
table is changed on first boot with extra storage provided by the hypervisor.

However, one essentially never wants to do this with real physical
disks.

The growpart logic is disabled by default, and virtualization images
should be tweaked to turn it on.  For example, the Fedora
spin-kickstarts git module has a kickstart file with a %post that
would be an appropriate place.

### Performance optimizations

 - docker-storage-setup: Skip block zeroing in thin pool
 - docker-storage-setup: Use chunk size 512K by default

Will make Docker devicemapper usage faster.

