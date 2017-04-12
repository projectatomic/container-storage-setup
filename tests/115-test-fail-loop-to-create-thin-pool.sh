source $SRCDIR/libtest.sh

test_fail_if_loop_partition_passed() {
  local lbdevice tmpfile
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage
  local tmplog=${WORKDIR}/tmplog
  local errmsg="Partition specification unsupported at this time."

  # Error out if any pre-existing volume group vg named css-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create loopback device.
   tmpfile=$(mktemp /tmp/c-s-s.XXXXXX)
   truncate --size=6G $tmpfile
   lbdevice=$(losetup -f)
   losetup --partscan $lbdevice $tmpfile
   if ! create_partition $lbdevice;then
      echo "ERROR: Failed partitioning $lbdevice"
      cleanup_loop_device "$tmpfile" "$lbdevice"
      return $test_status
   fi

  cat << EOF > $infile
DEVS="${lbdevice}p1"
VG=$vg_name
CONTAINER_THINPOOL=container-thinpool
EOF

  local create_cmd="$CSSBIN create -o $outfile $CSS_TEST_CONFIG $infile"
  # Run container-storage-setup
  $create_cmd >> $tmplog 2>&1
  rc=$?
  cat $tmplog >> $LOGS 2>&1

  # Test failed.
  if [ $rc -ne 0 ]; then
      if grep --no-messages -q "$errmsg" $tmplog; then
	  test_status=0
      else
	  echo "ERROR: $testname: $CSSBIN Failed for a reason other then \"$errmsg\"" >> $LOGS
      fi
  else
      echo "ERROR: $testname: $CSSBIN Succeeded. Should have failed since ${lbdevice}p1 is a loop device partition." >> $LOGS
  fi
  cleanup $vg_name "$lbdevice" "$infile" "$outfile"
  cleanup_loop_device "$tmpfile" "$lbdevice"
  return $test_status
}

cleanup_loop_device() {
  local tmpfile=$1
  local lbdevice=$2
  losetup -d $lbdevice
  rm $tmpfile > /dev/null 2>&1
}

# Make sure command fails if loop device partition /dev/loop0p1 is passed.
test_fail_if_loop_partition_passed

