source $SRCDIR/libtest.sh

# Test DOCKER_ROOT_VOLUME= directive. Returns 0 on success and 1 on failure.
test_docker_root_volume() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  local docker_root_lv_name="docker-root-lv"

  # Error out if any pre-existing volume group vg named dss-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create config file
  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
DOCKER_ROOT_VOLUME=yes
EOF

 # Run container-storage-setup
 $DSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN failed." >> $LOGS
    cleanup $vg_name "$devs"
    return $test_status
 fi

  # Make sure $DOCKER_ROOT_VOLUME {docker-root-lv} got created
  # successfully.
  if ! lv_exists "$vg_name" "$docker_root_lv_name"; then
    echo "ERROR: $testname: Logical Volume $docker_root_lv_name does not exist." >> $LOGS
    cleanup $vg_name "$devs"
    return $test_status
  fi

  # Make sure $DOCKER_ROOT_VOLUME {docker-root-lv} is
  # mounted on /var/lib/docker
  local mnt
  mnt=$(findmnt -n -o TARGET --first-only --source /dev/${vg_name}/${docker_root_lv_name})
  if [ "$mnt" != "/var/lib/docker" ];then
   echo "ERROR: $testname: Logical Volume $docker_root_lv_name is not mounted on /var/lib/docker." >> $LOGS
   cleanup $vg_name "$devs"
   return $test_status
  fi

  cleanup_container_root_volume $vg_name $docker_root_lv_name $mnt
  cleanup $vg_name "$devs"
  return 0
}

cleanup_container_root_volume(){
  local vg_name=$1
  local lv_name=$2
  local mount_path=$3

  umount $mount_path >> $LOGS 2>&1
  lvchange -an $vg_name/${lv_name} >> $LOGS 2>&1
  lvremove $vg_name/${lv_name} >> $LOGS 2>&1

  cleanup_mount_file $mount_path
}

test_docker_root_volume
