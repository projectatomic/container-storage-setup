source $SRCDIR/libtest.sh

# We recently changed default storage driver to overlay2. That change
# takes affect only over fresh installation and not over upgrade. But
# in atomic, even over upgrade it overwrites existing
# /etc/sysconfig/docker-storage-setup file and after upgrade storage reset
# does not reset thin pool thinking storage driver is not devicemapper.

# Make sure thinpool can be reset even after atomic upgrade.
test_storage_driver_reset() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"

  # Error out if any pre-existing volume group vg named css-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create config file
  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
EOF

 # Run container-storage-setup
 $CSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $CSSBIN failed." >> $LOGS
    cleanup $vg_name "$devs"
    return $test_status
 fi

  # Make sure volume group $VG got created
  if ! vg_exists "$vg_name"; then
    echo "ERROR: $testname: $CSSBIN failed. $vg_name was not created." >> $LOGS
    cleanup $vg_name "$devs"
    return $test_status
  fi

  # Overwrite config file
  cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=overlay2
EOF
  # Reset storage
  $CSSBIN --reset >> $LOGS 2>&1

  # Test failed.
  if [ $? -eq 0 ]; then
     if [ -e /etc/sysconfig/docker-storage ]; then
         echo "ERROR: $testname: $CSSBIN failed. /etc/sysconfig/docker-storage still exists." >> $LOGS
     else
         if lv_exists $vg_name "docker-pool"; then
             echo "ERROR: $testname: Thin pool docker-pool still exists." >> $LOGS
         else
             test_status=0
         fi
     fi
  fi

  if [ $test_status -ne 0 ]; then
      echo "ERROR: $testname: $CSSBIN --reset failed." >> $LOGS
  fi

  cleanup $vg_name "$devs"
  return $test_status
}

test_storage_driver_reset

