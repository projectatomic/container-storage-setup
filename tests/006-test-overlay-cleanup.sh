source $SRCDIR/libtest.sh

# Test "docker-storage-setup reset". Returns 0 on success and 1 on failure.
test_reset_overlay() {
  local test_status=0
  local testname=`basename "$0"`
  local infile=/etc/sysconfig/docker-storage-setup
  local outfile=/etc/sysconfig/docker-storage

  cat << EOF > ${infile}
STORAGE_DRIVER=overlay
EOF

 # Run docker-storage-setup
 $DSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN failed." >> $LOGS
    clean_config_files $infile $outfile
    return 1
 fi

 $DSSBIN --reset >> $LOGS 2>&1
 if [ $? -ne 0 ]; then
    # Test failed.
    echo "ERROR: $testname: $DSSBIN --reset failed." >> $LOGS
    test_status=1
 elif [ -e /etc/sysconfig/docker-storage ]; then
    # Test failed.
    echo "ERROR: $testname: $DSSBIN --reset failed to cleanup /etc/sysconfig/docker." >> $LOGS
    test_status=1
 fi

 clean_config_files $infile $outfile
 return $test_status
}

# Create a overlay backend and then make sure the
# docker-storage-setup --reset
# cleans it up properly.
test_reset_overlay
