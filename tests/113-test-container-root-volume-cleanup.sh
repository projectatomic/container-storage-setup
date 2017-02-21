source $SRCDIR/libtest.sh

# Test "container-storage-setup --reset" for CONTAINER_ROOT_LV_NAME=
# and CONTAINER_ROOT_LV_MOUNT_PATH= directives.
# Returns 0 on success and 1 on failure.
test_reset_container_root_volume() {
  local devs=${TEST_DEVS}
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  local root_lv_name="container-root-lv"
  local root_lv_mount_path="/var/lib/containers"
  local mount_filename="var-lib-containers.mount"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  # Error out if any pre-existing volume group vg named dss-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  cat << EOF > $infile
DEVS="$devs"
VG=$vg_name
CONTAINER_ROOT_LV_NAME=$root_lv_name
CONTAINER_ROOT_LV_MOUNT_PATH=$root_lv_mount_path
CONTAINER_THINPOOL=container-thinpool
EOF

  # Run container-storage-setup
  $DSSBIN $infile $outfile >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN failed." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
  fi

  $DSSBIN --reset $infile $outfile >> $LOGS 2>&1
  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN --reset failed." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
  fi

  if ! everything_clean $vg_name $root_lv_name $mount_filename;then
    echo "ERROR: $testname: $DSSBIN --reset did not cleanup everything as needed." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
  fi
  cleanup $vg_name "$devs" "$infile" "$outfile"
  return 0
}

everything_clean(){
  local vg_name=$1
  local lv_name=$2
  local mount_filename=$3
  if [ -e "$outfile" ] || [ -e "/etc/systemd/system/${mount_filename}" ]; then
    return 1
  fi
  if lv_exists "$vg_name" "$lv_name";then
    return 1
  fi
  return 0
}

cleanup_all(){
  local vg_name=$1
  local lv_name=$2
  local mount_path=$3
  local devs=$4
  local infile=$5
  local outfile=$6

  umount $mount_path >> $LOGS 2>&1
  lvchange -an $vg_name/${lv_name} >> $LOGS 2>&1
  lvremove $vg_name/${lv_name} >> $LOGS 2>&1

  cleanup_mount_file $mount_path
  cleanup $vg_name "$devs" "$infile" "$outfile"
}


# If a user has specified CONTAINER_ROOT_LV_NAME="container-root-lv"
# and CONTAINER_ROOT_LV_MOUNT_PATH="/var/lib/containers", then
# container-storage-setup would create a logical volume named
# "container-root-lv" and mount it on "/var/lib/containers".
# This function tests if `container-storage-setup --reset`
# cleans it up properly.
test_reset_container_root_volume
