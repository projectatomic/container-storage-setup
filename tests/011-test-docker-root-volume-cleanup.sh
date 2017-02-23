source $SRCDIR/libtest.sh

# Test "container-storage-setup --reset" for DOCKER_ROOT_VOLUME=yes.
# Returns 0 on success and 1 on failure.
test_reset_docker_root_volume() {
  local devs=${TEST_DEVS}
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"
  local mount_path="/var/lib/docker"
  local mount_filename="var-lib-docker.mount"
  local docker_root_lv_name="docker-root-lv"

  # Error out if any pre-existing volume group vg named css-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
DOCKER_ROOT_VOLUME=yes
EOF

  # Run container-storage-setup
  $CSSBIN >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $CSSBIN failed." >> $LOGS
    cleanup_all $vg_name $docker_root_lv_name $mount_path "$devs"
    return $test_status
  fi

  $CSSBIN --reset >> $LOGS 2>&1
  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $CSSBIN --reset failed." >> $LOGS
    cleanup_all $vg_name $docker_root_lv_name $mount_path "$devs"
    return $test_status
  fi

  if ! everything_clean $vg_name $docker_root_lv_name $mount_filename;then
    echo "ERROR: $testname: $CSSBIN --reset did not cleanup everything as needed." >> $LOGS
    cleanup_all $vg_name $docker_root_lv_name $mount_path "$devs"
    return $test_status
  fi
  cleanup $vg_name "$devs"
  return 0
}

everything_clean(){
  local vg_name=$1
  local docker_root_lv_name=$2
  local mount_filename=$3
  if [ -e "/etc/sysconfig/docker-storage" ] || [ -e "/etc/systemd/system/${mount_filename}" ]; then
    return 1
  fi
  if lv_exists "$vg_name" "$docker_root_lv_name";then
    return 1
  fi
  return 0
}

cleanup_all(){
  local vg_name=$1
  local lv_name=$2
  local mount_path=$3
  local devs=$4

  umount $mount_path >> $LOGS 2>&1
  lvchange -an $vg_name/${lv_name} >> $LOGS 2>&1
  lvremove $vg_name/${lv_name} >> $LOGS 2>&1

  cleanup_mount_file $mount_path
  cleanup $vg_name "$devs"
}

#If a user has specified DOCKER_ROOT_VOLUME=yes
#container-storage-setup sets up a logical volume
#named "docker-root-lv" and mounts it on docker
#root directory. This function tests if
#`container-storage-setup --reset` cleans it up properly.
test_reset_docker_root_volume
