#!/bin/bash

clean_config_files() {
  rm -f /etc/sysconfig/docker-storage-setup
  rm -f /etc/sysconfig/docker-storage
}

remove_pvs() {
  local devs=$1
  # Assume $dev1 is pv to remove.
  for dev in $devs; do
    pvremove -y ${dev}1 >> $LOGS 2>&1
  done
}

remove_partitions() {
  local devs=$1

  # Assume partition number 1 is to be removed.
  for dev in $devs; do
    parted ${dev} rm 1 >> $LOGS 2>&1
  done
}

# Wipe all signatures on devices
wipe_signatures() {
  local devs=$1
  for dev in $devs; do
    wipefs -a $dev >> $LOGS 2>&1
  done
}

cleanup() {
  local vg_name=$1
  local devs=$2

  vgremove -y $vg_name >> $LOGS 2>&1
  remove_pvs "$devs"
  remove_partitions "$devs"
  clean_config_files
  wipe_signatures "$devs"
}
