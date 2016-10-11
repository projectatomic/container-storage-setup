#!/bin/bash

#--
# Copyright 2014-2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++

#  Purpose:  This script grows the root filesystem and sets up LVM volumes
#            for docker metadata and data.
#  Author:   Andy Grimm <agrimm@redhat.com>

set -e

# This section reads the config file /etc/sysconfig/docker-storage-setup
# Currently supported options:
# DEVS: A quoted, space-separated list of devices to be used.  This currently
#       expects the devices to be unpartitioned drives.  If "VG" is not
#       specified, then use of the root disk's extra space is implied.
#
# VG:   The volume group to use for docker storage.  Defaults to the volume
#       group where the root filesystem resides.  If VG is specified and the
#       volume group does not exist, it will be created (which requires that
#       "DEVS" be nonempty, since we don't currently support putting a second
#       partition on the root disk).
#
# The options below should be specified as values acceptable to 'lvextend -L':
#
# ROOT_SIZE: The size to which the root filesystem should be grown.
#
# DATA_SIZE: The desired size for the docker data LV.  Defaults to using all
#            free space in the VG after the root LV and docker metadata LV
#            have been allocated/grown.
#
# Other possibilities:
# * Support lvm raid setups for docker data?  This would not be very difficult
#   if given multiple PVs and another variable; options could be just a simple
#   "mirror" or "stripe", or something more detailed.

# In lvm thin pool, effectively data LV is named as pool LV. lvconvert
# takes the data lv name and uses it as pool lv name. And later even to
# resize the data lv, one has to use pool lv name. So name data lv
# appropriately.
#
# Note: lvm2 version should be same or higher than lvm2-2.02.112 for lvm
#       thin pool functionality to work properly.
POOL_LV_NAME="docker-pool"
DATA_LV_NAME=$POOL_LV_NAME
META_LV_NAME="${POOL_LV_NAME}meta"

DOCKER_STORAGE="/etc/sysconfig/docker-storage"
STORAGE_DRIVERS="devicemapper overlay overlay2"

DOCKER_METADATA_DIR="/var/lib/docker"

PIPE1=/run/dss-fifo1
PIPE2=/run/dss-fifo2
TEMPDIR=$(mktemp --tmpdir -d)

# DEVS can have device names without absolute path. Convert these to absolute
# paths and save in ABS_DEVS and use in rest of the code.
DEVS_ABS=""

# Will have currently configured storage options in $DOCKER_STORAGE
CURRENT_STORAGE_OPTIONS=""

get_docker_version() {
  local version

  # docker version command exits with error as daemon is not running at this
  # point of time. So continue despite the error.
  version=`docker version --format='{{.Client.Version}}' 2>/dev/null` || true
  echo $version
}

get_deferred_removal_string() {
  local version major minor

  if ! version=$(get_docker_version);then
    return 0
  fi
  [ -z "$version" ] && return 0

  major=$(echo $version | cut -d "." -f1)
  minor=$(echo $version | cut -d "." -f2)
  [ -z "$major" ] && return 0
  [ -z "$minor" ] && return 0

  # docker 1.7 onwards supports deferred device removal. Enable it.
  if [ $major -gt 1 ] ||  ([ $major -eq 1 ] && [ $minor -ge 7 ]);then
    echo "--storage-opt dm.use_deferred_removal=true"
  fi
}

get_deferred_deletion_string() {
  local version major minor

  if ! version=$(get_docker_version);then
    return 0
  fi
  [ -z "$version" ] && return 0

  major=$(echo $version | cut -d "." -f1)
  minor=$(echo $version | cut -d "." -f2)
  [ -z "$major" ] && return 0
  [ -z "$minor" ] && return 0

  if should_enable_deferred_deletion $major $minor; then
     echo "--storage-opt dm.use_deferred_deletion=true"
  fi
}

should_enable_deferred_deletion() {
   # docker 1.9 onwards supports deferred device deletion. Enable it.
   local major=$1
   local minor=$2
   if [ $major -lt 1 ] || ([ $major -eq 1 ] && [ $minor -lt 9 ]);then
      return 1
   fi
   if platform_supports_deferred_deletion; then
      return 0
   fi
   return 1
}

platform_supports_deferred_deletion() {
        local deferred_deletion_supported=1
        trap cleanup_pipes EXIT
        mkfifo $PIPE1
        mkfifo $PIPE2
        mount -o bind $TEMPDIR $TEMPDIR
        if [ ! -x "/usr/lib/docker-storage-setup/dss-child-read-write" ];then
           return 1
        fi
        unshare -m /usr/lib/docker-storage-setup/dss-child-read-write $PIPE1 $PIPE2 &
        read -t 10 n <>$PIPE1
        if [ "$n" != "start" ];then
	   return 1
        fi
        umount $TEMPDIR
        rmdir $TEMPDIR > /dev/null 2>&1
        deferred_deletion_supported=$?
        echo "finish" > $PIPE2
        return $deferred_deletion_supported
}

cleanup_pipes(){
    rm -f $PIPE1
    rm -f $PIPE2
    rmdir $TEMPDIR 2>/dev/null
}

extra_options_has_dm_fs() {
  local option
  for option in ${EXTRA_DOCKER_STORAGE_OPTIONS}; do
    if grep -q "dm.fs=" <<< $option; then
      return 0
    fi
  done
  return 1
}

# Wait for a device for certain time interval. If device is found 0 is
# returned otherwise 1.
wait_for_dev() {
  local devpath=$1
  local timeout=$DEVICE_WAIT_TIMEOUT

  if [ -b "$devpath" ];then
    Info "Device node $devpath exists."
    return 0
  fi

  if [ -z "$DEVICE_WAIT_TIMEOUT" ] || [ "$DEVICE_WAIT_TIMEOUT" == "0" ];then
    Info "Not waiting for device $devpath as DEVICE_WAIT_TIMEOUT=${DEVICE_WAIT_TIMEOUT}."
    return 0
  fi

  while [ $timeout -gt 0 ]; do
    Info "Waiting for device $devpath to be available. Wait time remaining is $timeout seconds"
    if [ $timeout -le 5 ];then
      sleep $timeout
    else
      sleep 5
    fi
    timeout=$((timeout-5))
    if [ -b "$devpath" ]; then
      Info "Device node $devpath exists."
      return 0
    fi
  done

  Info "Timed out waiting for device $devpath"
  return 1
}

get_devicemapper_config_options() {
  local storage_options
  local dm_fs="--storage-opt dm.fs=xfs"

  # docker expects device mapper device and not lvm device. Do the conversion.
  eval $( lvs --nameprefixes --noheadings -o lv_name,kernel_major,kernel_minor $VG | while read line; do
    eval $line
    if [ "$LVM2_LV_NAME" = "$DATA_LV_NAME" ]; then
      echo POOL_DEVICE_PATH=/dev/mapper/$( cat /sys/dev/block/${LVM2_LV_KERNEL_MAJOR}:${LVM2_LV_KERNEL_MINOR}/dm/name )
    fi
  done )

  if extra_options_has_dm_fs; then
    # dm.fs option defined in ${EXTRA_DOCKER_STORAGE_OPTIONS}
    dm_fs=""
  fi

  storage_options="DOCKER_STORAGE_OPTIONS=\"--storage-driver devicemapper ${dm_fs} --storage-opt dm.thinpooldev=$POOL_DEVICE_PATH $(get_deferred_removal_string) $(get_deferred_deletion_string) ${EXTRA_DOCKER_STORAGE_OPTIONS}\""
  echo $storage_options
}

get_config_options() {
  if [ "$1" == "devicemapper" ]; then
    get_devicemapper_config_options
    return $?
  fi
  echo "DOCKER_STORAGE_OPTIONS=\"--storage-driver $1 ${EXTRA_DOCKER_STORAGE_OPTIONS}\""
  return 0
}

write_storage_config_file () {
  local storage_options

  if ! storage_options=$(get_config_options $STORAGE_DRIVER); then
      return 1
  fi

  cat <<EOF > $DOCKER_STORAGE.tmp
$storage_options
EOF

  mv $DOCKER_STORAGE.tmp $DOCKER_STORAGE
}

create_metadata_lv() {
  # If metadata lvm already exists (failures from previous run), then
  # don't create it.
  # TODO: Modify script to cleanup meta and data lvs if failure happened
  # later. Don't exit with error leaving partially created lvs behind.

  if lvs -a $VG/${META_LV_NAME} --noheadings &>/dev/null; then
    Info "Metadata volume $META_LV_NAME already exists. Not creating a new one."
    return 0
  fi

  # Reserve 0.1% of the free space in the VG for docker metadata.
  # Calculating the based on actual data size might be better, but is
  # more difficult do to the range of possible inputs.
  VG_SIZE=$( vgs --noheadings --nosuffix --units s -o vg_size $VG )
  META_SIZE=$(( $VG_SIZE / 1000 + 1 ))
  if [ ! -n "$META_LV_SIZE" ]; then
    lvcreate -y -L ${META_SIZE}s -n $META_LV_NAME $VG
  fi
}

convert_size_in_bytes() {
  local size=$1 prefix suffix

  # if it is all numeric, it is valid as by default it will be MiB.
  if [[ $size =~ ^[[:digit:]]+$ ]]; then
    echo $(($size*1024*1024))
    return 0
  fi

  # supprt G, G[bB] or Gi[bB] inputs.
  prefix=${size%[bBsSkKmMgGtTpPeE]i[bB]}
  prefix=${prefix%[bBsSkKmMgGtTpPeE][bB]}
  prefix=${prefix%[bBsSkKmMgGtTpPeE]}

  # if prefix is not all numeric now, it is an error.
  if ! [[ $prefix =~ ^[[:digit:]]+$ ]]; then
    return 1
  fi

  suffix=${data_size#$prefix}

  case $suffix in
    b*|B*) echo $prefix;;
    s*|S*) echo $(($prefix*512));;
    k*|K*) echo $(($prefix*2**10));;
    m*|M*) echo $(($prefix*2**20));;
    g*|G*) echo $(($prefix*2**30));;
    t*|T*) echo $(($prefix*2**40));;
    p*|P*) echo $(($prefix*2**50));;
    e*|E*) echo $(($prefix*2**60));;
    *) return 1;;
  esac
}

data_size_in_bytes() {
  local data_size=$1
  local bytes vg_size free_space percent

  # -L compatible syntax
  if [[ $DATA_SIZE != *%* ]]; then
    bytes=`convert_size_in_bytes $data_size`
    [ $? -ne 0 ] && return 1
    # If integer overflow took place, value is too large to handle.
    if [ $bytes -lt 0 ];then
      Error "DATA_SIZE=$data_size is too large to handle."
      return 1
    fi
    echo $bytes
    return 0
  fi

  if [[ $DATA_SIZE == *%FREE ]];then
    free_space=$(vgs --noheadings --nosuffix --units b -o vg_free $VG)
    percent=${DATA_SIZE%\%FREE}
    echo $((percent*free_space/100))
    return 0
  fi

  if [[ $DATA_SIZE == *%VG ]];then
    vg_size=$(vgs --noheadings --nosuffix --units b -o vg_size $VG)
    percent=${DATA_SIZE%\%VG}
    echo $((percent*vg_size/100))
  fi
  return 0
}

check_min_data_size_condition() {
  local min_data_size_bytes data_size_bytes free_space

  [ -z $MIN_DATA_SIZE ] && return 0

  if ! check_numeric_size_syntax $MIN_DATA_SIZE; then
    Fatal "MIN_DATA_SIZE value $MIN_DATA_SIZE is invalid."
  fi

  if ! min_data_size_bytes=$(convert_size_in_bytes $MIN_DATA_SIZE);then
    Fatal "Failed to convert MIN_DATA_SIZE to bytes"
  fi

  # If integer overflow took place, value is too large to handle.
  if [ $min_data_size_bytes -lt 0 ];then
    Fatal "MIN_DATA_SIZE=$MIN_DATA_SIZE is too large to handle."
  fi

  free_space=$(vgs --noheadings --nosuffix --units b -o vg_free $VG)

  if [ $free_space -lt $min_data_size_bytes ];then
    Fatal "There is not enough free space in volume group $VG to create data volume of size MIN_DATA_SIZE=${MIN_DATA_SIZE}."
  fi

  if ! data_size_bytes=$(data_size_in_bytes $DATA_SIZE);then
    Fatal "Failed to convert desired data size to bytes"
  fi

  if [ $data_size_bytes -lt $min_data_size_bytes ]; then
    # Increasing DATA_SIZE to meet minimum data size requirements.
    Info "DATA_SIZE=${DATA_SIZE} is smaller than MIN_DATA_SIZE=${MIN_DATA_SIZE}. Will create data volume of size specified by MIN_DATA_SIZE."
    DATA_SIZE=$MIN_DATA_SIZE
  fi
}

create_data_lv() {
  if [ ! -n "$DATA_SIZE" ]; then
    Fatal "Data volume creation failed. No DATA_SIZE specified"
  fi

  if ! check_data_size_syntax $DATA_SIZE; then
    Fatal "DATA_SIZE value $DATA_SIZE is invalid."
  fi

  check_min_data_size_condition

  # TODO: Error handling when DATA_SIZE > available space.
  if [[ $DATA_SIZE == *%* ]]; then
    lvcreate -y -l $DATA_SIZE -n $DATA_LV_NAME $VG
  else
    lvcreate -y -L $DATA_SIZE -n $DATA_LV_NAME $VG
  fi
}

create_lvm_thin_pool () {
  if [ -z "$DEVS_ABS" ] && [ -z "$VG_EXISTS" ]; then
    Fatal "Specified volume group $VG does not exist, and no devices were specified"
  fi

  # First create metadata lv. Down the line let lvm2 create it automatically.
  create_metadata_lv
  create_data_lv

  if [ -n "$CHUNK_SIZE" ]; then
    CHUNK_SIZE_ARG="-c $CHUNK_SIZE"
  fi
  lvconvert -y --zero n $CHUNK_SIZE_ARG --thinpool $VG/$DATA_LV_NAME --poolmetadata $VG/$META_LV_NAME
}

get_configured_thin_pool() {
  local options tpool opt

  options=$CURRENT_STORAGE_OPTIONS
  [ -z "$options" ] && return 0

  # This assumes that thin pool is specified as dm.thinpooldev=foo. There
  # are no spaces in between.
  for opt in $options; do
    if [[ $opt =~ dm.thinpooldev* ]];then
      tpool=${opt#*=}
      echo "$tpool"
      return 0
    fi
  done
}

check_docker_storage_metadata() {
  local docker_devmapper_meta_dir="$DOCKER_METADATA_DIR/devicemapper/metadata/"

  [ ! -d "$docker_devmapper_meta_dir" ] && return 0

  # Docker seems to be already using devicemapper storage driver. Error out.
  Error "Docker has been previously configured for use with devicemapper graph driver. Not creating a new thin pool as existing docker metadata will fail to work with it. Manual cleanup is required before this will succeed."
  Info "Docker state can be reset by stopping docker and by removing ${DOCKER_METADATA_DIR} directory. This will destroy existing docker images and containers and all the docker metadata."
  exit 1
}

reset_lvm_thin_pool () {
  if lvm_pool_exists; then
      lvchange -an $VG/${POOL_LV_NAME}
      lvremove $VG/${POOL_LV_NAME}
  fi
}

setup_lvm_thin_pool () {
  local tpool

  # Check if a thin pool is already configured in /etc/sysconfig/docker-storage.
  # If yes, wait for that thin pool to come up.
  tpool=`get_configured_thin_pool`

  if [ -n "$tpool" ]; then
     local escaped_pool_lv_name=`echo $POOL_LV_NAME | sed 's/-/--/g'`
     Info "Found an already configured thin pool $tpool in ${DOCKER_STORAGE}"

     # dss generated thin pool device name starts with /dev/mapper/ and
     # ends with POOL_LV_NAME
     if [[ "$tpool" != /dev/mapper/*${escaped_pool_lv_name} ]];then
       Fatal "Thin pool ${tpool} does not seem to be managed by docker-storage-setup. Exiting."
     fi

     if ! wait_for_dev "$tpool"; then
       Fatal "Already configured thin pool $tpool is not available. If thin pool exists and is taking longer to activate, set DEVICE_WAIT_TIMEOUT to a higher value and retry. If thin pool does not exist any more, remove ${DOCKER_STORAGE} and retry"
     fi
  fi

  # At this point of time, a volume group should exist for lvm thin pool
  # operations to succeed. Make that check and fail if that's not the case.
  if ! vg_exists "$VG";then
    Fatal "No valid volume group found. Exiting."
  else
    VG_EXISTS=1
  fi

  if ! lvm_pool_exists; then
    check_docker_storage_metadata
    create_lvm_thin_pool
    write_storage_config_file
  else
    # At this point /etc/sysconfig/docker-storage file should exist. If user
    # deleted this file accidently without deleting thin pool, recreate it.
    if [ ! -f "$DOCKER_STORAGE" ];then
      Info "$DOCKER_STORAGE file is missing. Recreating it."
      write_storage_config_file
    fi
  fi

  # Enable or disable automatic pool extension
  if [ "$AUTO_EXTEND_POOL" == "yes" ];then
    enable_auto_pool_extension ${VG} ${POOL_LV_NAME}
  else
    disable_auto_pool_extension ${VG} ${POOL_LV_NAME}
  fi
}

lvm_pool_exists() {
  local lv_data
  local lvname lv lvsize

  lv_data=$( lvs --noheadings -o lv_name,lv_attr --separator , $VG | sed -e 's/^ *//')
  SAVEDIFS=$IFS
  for lv in $lv_data; do
  IFS=,
  read lvname lvattr <<< "$lv"
    # pool logical volume has "t" as first character in its attributes
    if [ "$lvname" == "$POOL_LV_NAME" ] && [[ $lvattr == t* ]]; then
      IFS=$SAVEDIFS
      return 0
    fi
  done
  IFS=$SAVEDIFS

  return 1
}

# If a /etc/sysconfig/docker-storage file is present and if it contains
# dm.datadev or dm.metadatadev entries, that means we have used old mode
# in the past.
is_old_data_meta_mode() {
  if [ ! -f "$DOCKER_STORAGE" ];then
    return 1
  fi

  if ! grep -e "^DOCKER_STORAGE_OPTIONS=.*dm\.datadev" -e "^DOCKER_STORAGE_OPTIONS=.*dm\.metadatadev" $DOCKER_STORAGE  > /dev/null 2>&1;then
    return 1
  fi

  return 0
}

grow_root_pvs() {
  # If root is not in a volume group, then there are no root pvs and nothing
  # to do.
  [ -z "$ROOT_PVS" ] && return 0

  # Grow root pvs only if user asked for it through config file.
  [ "$GROWPART" != "true" ] && return

  if [ ! -x "/usr/bin/growpart" ];then
    Error "GROWPART=true is specified and /usr/bin/growpart executable is not available. Install /usr/bin/growpart and try again."
    return 1
  fi

  # Note that growpart is only variable here because we may someday support
  # using separate partitions on the same disk.  Today we fail early in that
  # case.  Also note that the way we are doing this, it should support LVM
  # RAID for the root device.  In the mirrored or striped case, we are growing
  # partitions on all disks, so as long as they match, growing the LV should
  # also work.
  for pv in $ROOT_PVS; do
    # Split device & partition.  Ick.
    growpart $( echo $pv | sed -r 's/([^0-9]*)([0-9]+)/\1 \2/' ) || true
    pvresize $pv
  done
}

grow_root_lv_fs() {
  if [ -n "$ROOT_SIZE" ]; then
    # TODO: Error checking if specified size is <= current size
    lvextend -r -L $ROOT_SIZE $ROOT_DEV || true
  fi
}

# Determines if a device is already added in a volume group as pv. Returns
# 0 on success.
is_dev_part_of_vg() {
  local dev=$1
  local vg=$2

  if ! pv_name=$(pvs --noheadings -o pv_name -S pv_name=$dev,vg_name=$vg); then
    Fatal "Error running command pvs. Exiting."
  fi

 [ -z "$pv_name" ] && return 1
 pv_name=`echo $pv_name | tr -d '[ ]'`
 [ "$pv_name" == "$dev" ] && return 0
 return 1
}

# Check if passed in vg exists. Returns 0 if volume group exists.
vg_exists() {
  local check_vg=$1

  for vg_name in $(vgs --noheadings -o vg_name); do
    if [ "$vg_name" == "$VG" ]; then
      return 0
    fi
  done
  return 1
}

is_block_dev_partition() {
  local bdev=$1

  if ! disktype=$(lsblk -n --nodeps --output type ${bdev}); then
    Fatal "Failed to run lsblk on device $bdev"
  fi

  if [ "$disktype" == "part" ];then
    return 0
  fi

  return 1
}

check_wipe_block_dev_sig() {
  local bdev=$1
  local sig

  if ! sig=$(wipefs -p $bdev); then
    Fatal "Failed to check signatures on device $bdev"
  fi

  [ "$sig" == "" ] && return 0

  if [ "$WIPE_SIGNATURES" == "true" ];then
    Info "Wipe Signatures is set to true. Any signatures on $bdev will be wiped."
    if ! wipefs -a $bdev; then
      Fatal "Failed to wipe signatures on device $bdev"
    fi
    return 0
  fi

  while IFS=, read offset uuid label type; do
    [ "$offset" == "# offset" ] && continue
    Fatal "Found $type signature on device ${bdev} at offset ${offset}. Wipe signatures using wipefs or use WIPE_SIGNATURES=true and retry."
  done <<< "$sig"
}

# Make sure passed in devices are valid block devies. Also make sure they
# are not partitions. Names which are of the form "sdb", convert them to
# their absolute path for processing in rest of the script.
canonicalize_block_devs() {
  local devs=$1 dev
  local devs_abs dev_abs

  for dev in ${devs}; do
    # Looks like we allowed just device name (sda) as valid input. In
    # such cases /dev/$dev should be a valid block device.
    dev_abs=$dev
    [ ! -b "$dev" ] && dev_abs="/dev/$dev"
    [ ! -b "$dev_abs" ] && Fatal "$dev_abs is not a valid block device."

    if is_block_dev_partition ${dev_abs}; then
      Fatal "Partition specification unsupported at this time."
    fi
    devs_abs="$devs_abs $dev_abs"
  done

  # Return list of devices to caller.
  echo "$devs_abs"
}

# Scans all the disks listed in DEVS= and returns the disks which are not
# already part of volume group and are new and require further processing.
scan_disks() {
  local new_disks=""

  for dev in $DEVS_ABS; do
    local basename=$(basename $dev)
    local p

    if is_dev_part_of_vg ${dev}1 $VG; then
      Info "Device ${dev} is already partitioned and is part of volume group $VG"
      continue
    fi

    # If signatures are being overridden, then simply return the disk as new
    # disk. Even if it is partitioned, partition signatures will be wiped.
    if [ "$WIPE_SIGNATURES" == "true" ];then
      new_disks="$new_disks $dev"
      continue
    fi

    # If device does not have partitions, it is a new disk requiring processing.
    p=$(awk "\$4 ~ /${basename}./ {print \$4}" /proc/partitions)
    if [[ -z "$p" ]]; then
      new_disks="$dev $new_disks"
      continue
    fi

    Fatal "Device $dev is already partitioned and cannot be added to volume group $VG"
  done

  echo $new_disks
}

create_partition() {
  local dev="$1" size

  # Use a single partition of a whole device
  # TODO:
  #   * Consider gpt, or unpartitioned volumes
  #   * Error handling when partition(s) already exist
  #   * Deal with loop/nbd device names. See growpart code
  size=$(( $( awk "\$4 ~ /"$( basename $dev )"/ { print \$3 }" /proc/partitions ) * 2 - 2048 ))
    cat <<EOF | sfdisk $dev
unit: sectors

${dev}1 : start=     2048, size=  ${size}, Id=8e
EOF

  # Sometimes on slow storage it takes a while for partition device to
  # become available. Wait for device node to show up.
  if ! udevadm settle;then
    Fatal "udevadm settle after partition creation failed. Exiting."
  fi

  if ! wait_for_dev ${dev}1; then
    Fatal "Partition device ${dev}1 is not available"
  fi
}

create_disk_partitions() {
  local devs="$1"

  for dev in $devs; do
    create_partition $dev

    # By now we have ownership of disk and we have checked there are no
    # signatures on disk or signatures should be wiped. Don't care
    # about any signatures found in the middle of disk after creating
    # partition and wipe signatures if any are found.
    if ! wipefs -a ${dev}1; then
      Fatal "Failed to wipe signatures on device ${dev}1"
    fi
    pvcreate ${dev}1
    PVS="$PVS ${dev}1"
  done
}

create_extend_volume_group() {
  if [ -z "$VG_EXISTS" ]; then
    vgcreate $VG $PVS
    VG_EXISTS=1
  else
    # TODO:
    #   * Error handling when PV is already part of a VG
    vgextend $VG $PVS
  fi
}

# Auto extension logic. Create a profile for pool and attach that profile
# the pool volume.
enable_auto_pool_extension() {
  local volume_group=$1
  local pool_volume=$2
  local profileName="${volume_group}--${pool_volume}-extend"
  local profileFile="${profileName}.profile"
  local profileDir
  local tmpFile=`mktemp -t tmp.XXXXX`

  profileDir=$(lvm dumpconfig | grep "profile_dir" | cut -d "=" -f2 | sed 's/"//g')
  [ -n "$profileDir" ] || return 1

  if [ ! -n "$POOL_AUTOEXTEND_THRESHOLD" ];then
    Error "POOL_AUTOEXTEND_THRESHOLD not specified"
    return 1
  fi

  if [ ! -n "$POOL_AUTOEXTEND_PERCENT" ];then
    Error "POOL_AUTOEXTEND_PERCENT not specified"
    return 1
  fi

  cat <<EOF > $tmpFile
activation {
	thin_pool_autoextend_threshold=${POOL_AUTOEXTEND_THRESHOLD}
	thin_pool_autoextend_percent=${POOL_AUTOEXTEND_PERCENT}

}
EOF
  mv $tmpFile ${profileDir}/${profileFile}
  lvchange --metadataprofile ${profileName}  ${volume_group}/${pool_volume}
}

disable_auto_pool_extension() {
  local volume_group=$1
  local pool_volume=$2
  local profileName="${volume_group}--${pool_volume}-extend"
  local profileFile="${profileName}.profile"
  local profileDir

  profileDir=$(lvm dumpconfig | grep "profile_dir" | cut -d "=" -f2 | sed 's/"//g')
  [ -n "$profileDir" ] || return 1

  lvchange --detachprofile ${volume_group}/${pool_volume}
  rm -f ${profileDir}/${profileFile}
}


# Gets the current DOCKER_STORAGE_OPTIONS= string.
get_docker_storage_options() {
  local options

  if [ ! -f "$DOCKER_STORAGE" ];then
    return 0
  fi

  if options=$(grep -e "^DOCKER_STORAGE_OPTIONS=" $DOCKER_STORAGE | sed 's/DOCKER_STORAGE_OPTIONS=//' | sed 's/^ *//' | sed 's/^"//' | sed 's/"$//');then
    echo $options
    return 0
  fi

  return 1
}

is_valid_storage_driver() {
  local driver=$1 d

  for d in $STORAGE_DRIVERS;do
    [ "$driver" == "$d" ] && return 0
  done

  return 1
}

# Gets the existing storage driver configured in /etc/sysconfig/docker-storage
get_existing_storage_driver() {
  local options driver

  options=$CURRENT_STORAGE_OPTIONS

  [ -z "$options" ] && return 0

  # Check if -storage-driver <driver> is there.
  if ! driver=$(echo $options | sed -n 's/.*\(--storage-driver [ ]*[a-z0-9]*\).*/\1/p' | sed 's/--storage-driver *//');then
    return 1
  fi

  # If pattern does not match then driver == options.
  if [ -n "$driver" ] && [ ! "$driver" == "$options" ];then
    echo $driver
    return 0
  fi

  # Check if -s <driver> is there.
  if ! driver=$(echo $options | sed -n 's/.*\(-s [ ]*[a-z][0-9]*\).*/\1/p' | sed 's/-s *//');then
    return 1
  fi

  # If pattern does not match then driver == options.
  if [ -n "$driver" ] && [ ! "$driver" == "$options" ];then
    echo $driver
    return 0
  fi

  # We shipped some versions where we did not specify -s devicemapper.
  # If dm.thinpooldev= is present driver is devicemapper.
  if echo $options | grep -q -e "--storage-opt dm.thinpooldev=";then
    echo "devicemapper"
    return 0
  fi

  #Failed to determine existing storage driver.
  return 1
}

setup_storage() {
  local current_driver

  if [ "$STORAGE_DRIVER" == "" ];then
    Info "No storage driver specified. Specify one using STORAGE_DRIVER option."
    exit 0
  fi

  if ! is_valid_storage_driver $STORAGE_DRIVER;then
    Fatal "Invalid storage driver: ${STORAGE_DRIVER}."
  fi

  # Query and save current storage options
  if ! CURRENT_STORAGE_OPTIONS=$(get_docker_storage_options); then
    return 1
  fi

  if ! current_driver=$(get_existing_storage_driver);then
    Fatal "Failed to determine existing storage driver."
  fi

  # If storage is configured and new driver should match old one.
  if [ -n "$current_driver" ] && [ "$current_driver" != "$STORAGE_DRIVER" ];then
   Fatal "Storage is already configured with ${current_driver} driver. Can't configure it with ${STORAGE_DRIVER} driver. To override, remove $DOCKER_STORAGE and retry."
  fi

  # Set up lvm thin pool LV
  if [ "$STORAGE_DRIVER" == "devicemapper" ]; then
    setup_lvm_thin_pool
  else
      write_storage_config_file
  fi
}

reset_storage() {
    if [ "$STORAGE_DRIVER" == "devicemapper" ]; then
	reset_lvm_thin_pool
    fi
    rm -f $DOCKER_STORAGE
}

usage() {
  cat <<-FOE
    Usage: $1 [OPTIONS]

    Grows the root filesystem and sets up storage for docker

    Options:
      --help    Print help message
      --reset   Reset your docker storage to init state. 
FOE
}

# Source library. If there is a library present in same dir as d-s-s, source
# that otherwise fall back to standard library. This is useful when modifyin
# libdss.sh in git tree and testing d-s-s.
SRCDIR=`dirname $0`

if [ -e $SRCDIR/libdss.sh ]; then
  source $SRCDIR/libdss.sh
elif [ -e /usr/lib/docker-storage-setup/libdss.sh ]; then
  source /usr/lib/docker-storage-setup/libdss.sh
fi

if [ -e /usr/lib/docker-storage-setup/docker-storage-setup ]; then
  source /usr/lib/docker-storage-setup/docker-storage-setup
fi

# If user has overridden any settings in /etc/sysconfig/docker-storage-setup
# take that into account.
if [ -e /etc/sysconfig/docker-storage-setup ]; then
  source /etc/sysconfig/docker-storage-setup
fi

# Read mounts
ROOT_DEV=$( awk '$2 ~ /^\/$/ && $1 !~ /rootfs/ { print $1 }' /proc/mounts )
if ! ROOT_VG=$(lvs --noheadings -o vg_name $ROOT_DEV 2>/dev/null);then
  Info "Volume group backing root filesystem could not be determined"
  ROOT_VG=
else
  ROOT_VG=$(echo $ROOT_VG | sed -e 's/^ *//' -e 's/ *$//')
fi

ROOT_PVS=
if [ -n "$ROOT_VG" ];then
  ROOT_PVS=$( pvs --noheadings -o pv_name,vg_name | awk "\$2 ~ /^$ROOT_VG\$/ { print \$1 }" )
fi

VG_EXISTS=
if [ -z "$VG" ]; then
  if [ -n "$ROOT_VG" ]; then
    VG=$ROOT_VG
    VG_EXISTS=1
  fi
else
  if vg_exists "$VG";then
    VG_EXISTS=1
  fi
fi

# Main Script

if [ $# -gt 0 ]; then
    if [ "$1" == "--help" ]; then
	usage $(basename $0)
	exit 0
    elif [ "$1" == "--reset" ]; then
	reset_storage
	exit 0
    else
        usage $(basename $0) >&2
	exit 1
    fi
fi

# If there is no volume group specified or no root volume group, there is
# nothing to do in terms of dealing with disks.
if [[ -n "$DEVS" && -n "$VG" ]]; then
  DEVS_ABS=$(canonicalize_block_devs "${DEVS}")

  # If all the disks have already been correctly partitioned, there is
  # nothing more to do
  P=$(scan_disks)
  if [[ -n "$P" ]]; then
    for dev in $P; do
      check_wipe_block_dev_sig $dev
    done
    create_disk_partitions "$P"
    create_extend_volume_group
  fi
fi

grow_root_pvs

# NB: We are growing root here first, because when root and docker share a
# disk, we'll default to giving some portion of remaining space to docker.
# Do this operation only if root is on a logical volume.
[ -n "$ROOT_VG" ] && grow_root_lv_fs

if is_old_data_meta_mode; then
  Fatal "Old mode of passing data and metadata logical volumes to docker is not supported. Exiting."
fi

setup_storage
