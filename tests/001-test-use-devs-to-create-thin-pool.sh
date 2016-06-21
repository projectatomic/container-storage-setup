source $SRCDIR/libtest.sh

# Test DEVS= directive. Returns 0 on success and 1 on failure.
test_devs() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  
  # Error out if any pre-existing volume group vg named dss-test-foo  
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create config file
  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
EOF

 # Run docker-storage-setup
 $DSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    cleanup $vg_name "$devs"
    return $test_status
 fi
  
  # Make sure volume group $VG got created
  if vg_exists "$vg_name"; then
    test_status=0
  fi

  cleanup $vg_name "$devs"
  return $test_status
}

test_devs
