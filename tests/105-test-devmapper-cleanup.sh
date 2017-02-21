source $SRCDIR/libtest.sh

# Test "container-storage-setup --reset". Returns 0 on success and 1 on failure.
test_reset_devmapper() {
  local devs=${TEST_DEVS}
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  # Error out if any pre-existing volume group vg named dss-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  cat << EOF > $infile
DEVS="$devs"
VG=$vg_name
CONTAINER_THINPOOL=container-thinpool
EOF

 # Run container-storage-setup
 $DSSBIN $infile $outfile >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN failed." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
 fi
 
 # Make sure thinpool got created with the specified name CONTAINER_THINPOOL
 if lv_exists $vg_name "container-thinpool"; then
     $DSSBIN --reset $infile $outfile >> $LOGS 2>&1
     # Test failed.
     if [ $? -eq 0 ]; then
	 if [ -e $outfile ]; then
	     echo "ERROR: $testname: $DSSBIN --reset $infile $outfile failed. $outfile still exists." >> $LOGS
	 else
	     if lv_exists $vg_name "container-thinpool"; then
		 echo "ERROR: $testname: Thin pool container-thinpool still exists." >> $LOGS
	     else
		 test_status=0
	     fi
	 fi
     fi
     if [ $test_status -ne 0 ]; then
	 echo "ERROR: $testname: $DSSBIN --reset $infile $outfile failed." >> $LOGS
     fi
  else
     echo "ERROR: $testname: Thin pool container-thinpool did not get created." >> $LOGS
  fi

  cleanup $vg_name "$devs" "$infile" "$outfile"

  return $test_status
}

# Create a devicemapper docker backend and then make sure the
# `container-storage-setup --reset`
# cleans it up properly.
test_reset_devmapper
