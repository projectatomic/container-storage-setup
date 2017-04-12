source $SRCDIR/libtest.sh

# Test "container-storage-setup --reset". Returns 0 on success and 1 on failure.
test_reset_overlay() {
  local test_status=0
  local testname=`basename "$0"`
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  cat << EOF > $infile
STORAGE_DRIVER=overlay
EOF

 # Run container-storage-setup
 local create_cmd="$CSSBIN create -o $outfile $CSS_TEST_CONFIG $infile"
 local remove_cmd="$CSSBIN remove $CSS_TEST_CONFIG"

 $create_cmd >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $create_cmd failed." >> $LOGS
    rm -f $infile $outfile
    return 1
 fi

 $remove_cmd >> $LOGS 2>&1
 if [ $? -ne 0 ]; then
    # Test failed.
    echo "ERROR: $testname: $remove_cmd failed." >> $LOGS
    test_status=1
 fi

 rm -f $infile $outfile
 return $test_status
}

# Create a overlay backend and then make sure the
# container-storage-setup --reset
# cleans it up properly.
test_reset_overlay
