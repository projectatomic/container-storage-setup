source $SRCDIR/libtest.sh

test_fail_if_no_container_thinpool() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage
  local tmplog=${WORKDIR}/tmplog
  local errmsg="CONTAINER_THINPOOL must be defined for the devicemapper storage driver."
  # Error out if any pre-existing volume group vg named dss-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  cat << EOF > $infile
DEVS="$devs"
VG=$vg_name
EOF
  # Run container-storage-setup
  $DSSBIN $infile $outfile > $tmplog 2>&1
  rc=$?
  cat $tmplog >> $LOGS 2>&1

  # Test failed.
  if [ $rc -ne 0 ]; then
      if grep --no-messages -q "$errmsg" $tmplog; then
	  test_status=0
      else
	  echo "ERROR: $testname: $DSSBIN Failed for a reason other then \"$errmsg\"" >> $LOGS
      fi
  else
      echo "ERROR: $testname: $DSSBIN Succeeded. Should have failed with CONTAINER_THINPOOL specified" >> $LOGS
  fi
  cleanup $vg_name "$devs" "$infile" "$outfile"
  return $test_status
}

# Make sure command fails if no CONTAINER_THINPOOL is specified
test_fail_if_no_container_thinpool
