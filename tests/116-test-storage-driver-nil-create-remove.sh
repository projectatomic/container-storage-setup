source $SRCDIR/libtest.sh

test_storage_driver_none() {
  local test_status=1
  local testname=`basename "$0"`
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  cat << EOF > $infile
STORAGE_DRIVER=""
EOF

  # Run container-storage-setup
  local create_cmd="$CSSBIN create $CSS_TEST_CONFIG $infile"
  local activate_cmd="$CSSBIN activate $CSS_TEST_CONFIG"
  local deactivate_cmd="$CSSBIN deactivate $CSS_TEST_CONFIG"
  local remove_cmd="$CSSBIN remove $CSS_TEST_CONFIG"
  local list_cmd="$CSSBIN list $CSS_TEST_CONFIG"

  $create_cmd >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $create_cmd failed." >> $LOGS
    cleanup_all $infile $outfile
    return $test_status
  fi

  # Deactivate and Activate
  $deactivate_cmd >> $LOGS 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $deactivate_cmd failed." >> $LOGS
    cleanup_all $infile $outfile
    return $test_status
  fi

  $activate_cmd >> $LOGS 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $activate_cmd failed." >> $LOGS
    cleanup_all $infile $outfile
    return $test_status
  fi

  $remove_cmd >> $LOGS 2>&1
  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $remove_cmd failed." >> $LOGS
    cleanup_all $infile $outfile
    return $test_status
  fi

  # Make sure config is gone. List config command should fail.
  $list_cmd >> $LOGS 2>&1
  if [ $? -eq 0 ]; then
    echo "ERROR: $testname: Storage configuration $CSS_TEST_CONFIG is present even after removal." >> $LOGS
    cleanup_all $infile $outfile
    return $test_status
  fi

  cleanup_all "$infile" "$outfile"
  return 0
}

cleanup_all(){
  local infile=$1
  local outfile=$2

  rm -f "$infile" "$outfile"
  rm -rf "$CSS_METADATA_DIR"
}


# Make sure STORAGE_DRIVER="" works with all commands.
test_storage_driver_none
