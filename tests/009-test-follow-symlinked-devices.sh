source $SRCDIR/libtest.sh

test_follow_symlinked_devices() {
  local devs dev
  local devlinks devlink
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"

  # Create a symlink for a device and try to follow it
  for dev in $TEST_DEVS; do
    if [ ! -h $dev ]; then
      devlink="/tmp/$(basename $dev)-test.$$"
      ln -s $dev $devlink

      dev=$devlink
      devlinks="$devlinks $dev"
    fi
    devs="$devs $dev"
    echo "Using symlinke devices: $dev -> $(readlink -e $dev)" >> $LOGS 
  done

  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
EOF
  # Run container-storage-setup
  $CSSBIN >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $CSSBIN failed." >> $LOGS
    cleanup_soft_links "$devlinks"
    cleanup $vg_name "$TEST_DEVS"
    return $test_status
  fi

  # Make sure volume group $VG got created.
  if vg_exists "$vg_name"; then
    test_status=0
  else
    echo "ERROR: $testname: $CSSBIN failed. $vg_name was not created." >> $LOGS
  fi

  cleanup_soft_links "$devlinks"
  cleanup $vg_name "$TEST_DEVS"
  return $test_status
}

# Make sure symlinked disk names are supported.
test_follow_symlinked_devices
