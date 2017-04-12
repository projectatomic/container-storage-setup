source $SRCDIR/libtest.sh

# Test "container-storage-setup --reset". Returns 0 on success and 1 on failure.
test_reset_overlay2() {
  local test_status=0
  local testname=`basename "$0"`
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  cat << EOF > $infile
STORAGE_DRIVER=overlay2
EOF

 local create_cmd="$CSSBIN create -o $outfile $CSS_TEST_CONFIG $infile"
 local remove_cmd="$CSSBIN remove $CSS_TEST_CONFIG"

 # Run container-storage-setup
 $create_cmd >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $create_cmd failed." >> $LOGS
    rm -f $infile $outfile
    return 1
 fi

 if ! grep -q "overlay2" $outfile; then
    echo "ERROR: $testname: $outfile does not have string overlay2." >> $LOGS
    rm -f $infile $outfile
    return 1
 fi

 $remove_cmd >> $LOGS 2>&1
 if [ $? -ne 0 ]; then
    # Test failed.
    test_status=1
    echo "ERROR: $testname: $remove_cmd failed." >> $LOGS
 fi

 rm -f $infile $outfile
 return $test_status
}

# Create a overlay2 backend and then make sure the
# container-storage-setup --reset
# cleans it up properly.
test_reset_overlay2
