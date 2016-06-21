source $SRCDIR/libtest.sh

# Test "docker-storage-setup reset". Returns 0 on success and 1 on failure.
test_reset_overlay() {
  local test_status=0
  local testname=`basename "$0"`

  cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=overlay
EOF

 # Run docker-storage-setup
 $DSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN Failed." >> $LOGS
    clean_config_files
    return 1
 fi

 $DSSBIN --reset >> $LOGS 2>&1
 if [ $? -ne 0 ]; then
    # Test failed.
    test_status=1
 elif [ -e /etc/sysconfig/docker-storage ]; then
    # Test failed.
    test_status=1
 fi
  if [ ${test_status} -eq 1 ]; then
    echo "ERROR: $testname: $DSSBIN --reset Failed." >> $LOGS
  fi

 clean_config_files
 return $test_status
}

# Create a overlay docker backend and then make sure the
# docker-storage-setup --reset
# cleans it up properly.
test_reset_overlay
