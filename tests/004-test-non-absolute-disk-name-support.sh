source $SRCDIR/libtest.sh

test_non_absolute_disk_name() {
  local devs dev
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"

  # Remove prefix /dev/ from disk names to test if non-absolute disk
  # names work.
  for dev in $TEST_DEVS; do
    dev=${dev##/dev/}
    devs="$devs $dev"
  done

  # Error out if any pre-existing volume group vg named dss-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi
 
  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
EOF

  # Run docker-storage-setup
  $DSSBIN >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    cleanup $vg_name "$TEST_DEVS"
    return $test_status
  fi

  # Make sure volume group $VG got created.
  if vg_exists "$vg_name"; then
    test_status=0
  fi

  cleanup $vg_name "$TEST_DEVS"
  return $test_status
}

# Make sure non-absolute disk names are supported. Ex. sdb.
test_non_absolute_disk_name
