source $SRCDIR/libtest.sh

# We recently changed default storage driver to overlay2. That change
# takes affect only over fresh installation and not over upgrade. But
# in atomic, even over upgrade it overwrites existing
# /etc/sysconfig/docker-storage-setup file and after upgrade and reboot
# we don't wait for thin pool as we exit early thinking storage driver
# changed.

# Make sure, even if storage driver changed, we try to bring up existing
# thin pool.
test_storage_driver_change() {
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
  # Run container-storage-setup
  $CSSBIN >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $CSSBIN failed." >> $LOGS
  else
    test_status=0
  fi

  cleanup $vg_name "$devs"
  return $test_status
}

test_storage_driver_change

