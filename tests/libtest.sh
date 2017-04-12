#!/bin/bash

create_partition_sfdisk(){
  local dev="$1" size
  # Use a single partition of a whole device
  # TODO:
  #   * Consider gpt, or unpartitioned volumes
  #   * Error handling when partition(s) already exist
  #   * Deal with loop/nbd device names. See growpart code
  size=$(( $( awk "\$4 ~ /"$( basename $dev )"/ { print \$3 }" /proc/partitions ) * 2 - 2048 ))
    cat <<EOF | sfdisk $dev
unit: sectors

start=     2048, size=  ${size}, Id=8e
EOF
}

create_partition_parted(){
  local dev="$1"
  parted $dev --script mklabel msdos mkpart primary 0% 100% set 1 lvm on
}

# Partition a block device.
create_partition() {
  local dev="$1" part

  if [ -x "/usr/sbin/parted" ]; then
    create_partition_parted $dev
  else
    create_partition_sfdisk $dev
  fi

  # Sometimes on slow storage it takes a while for partition device to
  # become available. Wait for device node to show up.
  if ! udevadm settle;then
    return 1
  fi
  return 0
}

# Tests if the volume group vg_name exists
vg_exists() {
  local vg vg_name="$1"

  for vg in $(vgs --noheadings -o vg_name); do
    if [ "$vg" == "$vg_name" ]; then
      return 0
    fi
  done
  return 1
}

# Tests if the logical volume lv_name exists
lv_exists() {
  local vg_name=$1
  local lv_name=$2
  lvs $vg_name/$lv_name > /dev/null 2>&1 && return 0
  return 1
}

remove_pvs() {
  local dev devs=$1 pv
  for dev in $devs; do
    pv=$(lsblk -npl -o NAME "$dev" | tail -n +2 | head -1)
    pvremove -y ${pv} >> $LOGS 2>&1
  done
}

parted_del_partition() {
  local dev=$1
  parted ${dev} rm 1 >> $LOGS 2>&1
}

sfdisk_del_partition() {
  local dev=$1
  sfdisk --delete ${dev} 1 >> $LOGS 2>&1
}

remove_partitions() {
  local dev devs=$1
  local use_parted=false

  if [ -x "/usr/sbin/parted" ]; then
    use_parted=true
  fi

  for dev in $devs; do
    if [ "$use_parted" == "true" ]; then
      parted_del_partition "$dev"
    else
      sfdisk_del_partition "$dev"
    fi
  done
}

# Wipe all signatures on devices
wipe_signatures() {
  local dev devs=$1
  for dev in $devs; do
    wipefs -f -a $dev >> $LOGS 2>&1
  done
}

cleanup() {
  local vg_name=$1
  local devs=$2
  local infile=/etc/sysconfig/docker-storage-setup
  local outfile=/etc/sysconfig/docker-storage
  if [ $# -eq 4 ]; then
    infile=$3
    outfile=$4
  fi


  vgremove -y $vg_name >> $LOGS 2>&1
  remove_pvs "$devs"
  remove_partitions "$devs"
  # After removing partitions let udev settle down. In some
  # cases it has been observed that udev rule kept the device
  # busy.
  udevadm settle
  rm -f $infile $outfile
  wipe_signatures "$devs"
  [ -d "$CSS_METADATA_DIR" ] && rm -rf "$CSS_METADATA_DIR"
}

cleanup_mount_file() {
  local mount_path=$1
  local mount_filename=$(echo $mount_path|sed 's/\//-/g'|cut -c 2-)

  if [ -f "/etc/systemd/system/$mount_filename.mount" ];then
    systemctl disable $mount_filename.mount >/dev/null 2>&1
    rm /etc/systemd/system/$mount_filename.mount >/dev/null 2>&1
    systemctl daemon-reload
  fi
}

cleanup_soft_links() {
  local dev devs=$1

  for dev in $devs; do
    rm $dev
  done
}
