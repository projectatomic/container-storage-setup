source $SRCDIR/libtest.sh

# Test "container-storage-setup reset". Returns 0 on success and 1 on failure.
test_reset_overlay2() {
  local test_status=0
  local testname=`basename "$0"`
  local infile=/etc/sysconfig/docker-storage-setup
  local outfile=/etc/sysconfig/docker-storage

  cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=overlay2
EOF

 # Run container-storage-setup
 $DSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN failed." >> $LOGS
    rm -f $infile $outfile
    return 1
 fi

 if ! grep -q "overlay2" /etc/sysconfig/docker-storage; then
    echo "ERROR: $testname: /etc/sysconfig/docker-storage does not have string overlay2." >> $LOGS
    rm -f $infile $outfile
    return 1
 fi

 $DSSBIN --reset >> $LOGS 2>&1
 if [ $? -ne 0 ]; then
    # Test failed.
    test_status=1
    echo "ERROR: $testname: $DSSBIN --reset failed." >> $LOGS
 elif [ -e /etc/sysconfig/docker-storage ]; then
    # Test failed.
    test_status=1
    echo "ERROR: $testname: $DSSBIN /etc/sysconfig/docker-storage still exists." >> $LOGS
 fi

 rm -f $infile $outfile
 return $test_status
}

# Create a overlay2 backend and then make sure the
# container-storage-setup --reset
# cleans it up properly.
test_reset_overlay2
