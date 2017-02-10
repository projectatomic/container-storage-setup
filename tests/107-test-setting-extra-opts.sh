source $SRCDIR/libtest.sh

# Test that the user-specified options stored in
# EXTRA_STORAGE_OPTIONS actually end up in
# the storage config file, appended to the variable
# STORAGE_OPTIONS in $outfile
test_set_extra_opts() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  local extra_options="--storage-opt dm.fs=ext4"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  # Error out if volume group $vg_name exists already
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists" >> $LOGS
    return $test_status
  fi

  cat << EOF > $infile
DEVS="$devs"
VG=$vg_name
EXTRA_STORAGE_OPTIONS="$extra_options"
CONTAINER_THINPOOL=container-thinpool
EOF

  # Run docker-storage-setup
  $DSSBIN $infile $outfile >> $LOGS 2>&1

  # dss failed
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $DSSBIN --reset failed." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Check if storage config file was created by dss
  if [ ! -f $outfile ]; then
    echo "ERROR: $testname: $outfile file was not created." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  source $outfile

  # Search for $extra_options in $options.
  echo $STORAGE_OPTIONS | grep -q -- "$extra_options"

  # Successful appending to STORAGE_OPTIONS
  if [ $? -eq 0 ]; then
    test_status=0
  else
    echo "ERROR: $testname: failed. STORAGE_OPTIONS ${STORAGE_OPTIONS} does not include extra_options ${extra_options}." >> $LOGS
  fi

  cleanup $vg_name "$devs" "$infile" "$outfile"
  return $test_status
}

# Test that $EXTRA_STORAGE_OPTIONS is successfully written
# into $outfile
test_set_extra_opts
