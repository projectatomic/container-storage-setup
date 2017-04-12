source $SRCDIR/libtest.sh

test_container_root_volume_activation_deactivation() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"
  local root_lv_name="container-root-lv"
  local root_lv_mount_path="/var/lib/containers"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  # Error out if any pre-existing volume group vg named css-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create config file
  cat << EOF > $infile
DEVS="$devs"
VG=$vg_name
CONTAINER_ROOT_LV_NAME=$root_lv_name
CONTAINER_ROOT_LV_MOUNT_PATH=$root_lv_mount_path
CONTAINER_THINPOOL=container-thinpool
EOF

 # Run container-storage-setup
 local create_cmd="$CSSBIN create -o $outfile $CSS_TEST_CONFIG $infile"
 local deactivate_cmd="$CSSBIN deactivate $CSS_TEST_CONFIG"
 local activate_cmd="$CSSBIN activate $CSS_TEST_CONFIG"
 local list_cmd="$CSSBIN list $CSS_TEST_CONFIG"
 local config_status

 $create_cmd >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $create_cmd failed." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
 fi

  # Make sure $CONTAINER_ROOT_LV_NAME {container-root-lv} got created
  # successfully.
  if ! lv_exists "$vg_name" "$root_lv_name"; then
    echo "ERROR: $testname: Logical Volume $root_lv_name does not exist." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
  fi

  # Make sure $CONTAINER_ROOT_LV_NAME {container-root-lv} is
  # mounted on $CONTAINER_ROOT_LV_MOUNT_PATH {/var/lib/containers}
  local mnt
  mnt=$(findmnt -n -o TARGET --first-only --source /dev/${vg_name}/${root_lv_name})
  if [ "$mnt" != "$root_lv_mount_path" ];then
   echo "ERROR: $testname: Logical Volume $root_lv_name is not mounted on $root_lv_mount_path." >> $LOGS
   cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
   return $test_status
  fi

  # Deactivate configuration
 $deactivate_cmd >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $deactivate_cmd failed." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
 fi

 # Make sure configuration status changed to "invactive"
 config_status=`$list_cmd | grep "Status:" | cut -d " " -f2`
 if [ "$config_status" != "inactive" ];then
   echo "error: $testname: configuration status is $config_status. It should be inactive after deactivation." >> $LOGS
   cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
   return $test_status
 fi

 # Make sure mount path got unmounted and volume got deactivated.
  mnt=$(findmnt -n -o TARGET --first-only --source /dev/${vg_name}/${root_lv_name})
  if [ -n "$mnt" ];then
   echo "error: $testname: logical volume $root_lv_name is still mounted at $mnt after deactivation." >> $LOGS
   cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
   return $test_status
  fi

  if lv_is_active $vg_name $root_lv_name; then
   echo "ERROR: $testname: Logical Volume $root_lv_name is still active after deactivation." >> $LOGS
   cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
   return $test_status
  fi

  # Activate configuration
  $activate_cmd >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $activate_cmd failed." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
  fi

  # Make sure configuration status changed to "active"
  config_status=`$list_cmd | grep "Status:" | cut -d " " -f2`
  if [ "$config_status" != "active" ];then
    echo "error: $testname: configuration status is $config_status. It should be active after activation." >> $LOGS
    cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
    return $test_status
  fi

  if ! lv_is_active $vg_name $root_lv_name; then
   echo "ERROR: $testname: Logical Volume $root_lv_name is not active after activation." >> $LOGS
   cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
   return $test_status
  fi

  mnt=$(findmnt -n -o TARGET --first-only --source /dev/${vg_name}/${root_lv_name})
  if [ "$mnt" != "$root_lv_mount_path" ];then
   echo "ERROR: $testname: Logical Volume $root_lv_name is not mounted on $root_lv_mount_path." >> $LOGS
   cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
   return $test_status
  fi

  cleanup_all $vg_name $root_lv_name $root_lv_mount_path "$devs" $infile $outfile
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

# Test if activation/deactivation works with container root lv configuration
test_container_root_volume_activation_deactivation
