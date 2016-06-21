source $SRCDIR/libtest.sh

# Test "docker-storage-setup reset". Returns 0 on success and 1 on failure.
test_reset_devmapper() {
  local devs=${TEST_DEVS}
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"

  # Error out if any pre-existing volume group vg named dss-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi 

  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
EOF

 # Run docker-storage-setup
 $DSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN Failed." >> $LOGS
    cleanup $vg_name "$devs"
    return $test_status
 fi

  $DSSBIN --reset >> $LOGS 2>&1
  # Test failed.
  if [ $? -eq 0 ]; then
     if [ ! -e /etc/sysconfig/docker-storage ]; then
          test_status=0
     fi
  fi
  if [ ${test_status} -eq 1 ]; then
     echo "ERROR: $testname: $DSSBIN --reset Failed." >> $LOGS
  fi

  cleanup $vg_name "$devs"

  return $test_status
}

# Create a devicemapper docker backend and then make sure the
# `docker-storage-setup --reset`
# cleans it up properly.
test_reset_devmapper
