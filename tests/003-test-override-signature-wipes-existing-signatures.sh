source $SRCDIR/libtest.sh

test_override_signatures() {
  local devs=$TEST_DEVS dev
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"

  # Error out if vg_name VG exists already
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi 

  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
WIPE_SIGNATURES=true
EOF

  # create lvm signatures on disks
  for dev in $devs; do
    pvcreate -f $dev >> $LOGS 2>&1
  done

  # Run docker-storage-setup
  $DSSBIN >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    cleanup $vg_name "$devs"
    return $test_status
  fi

  # Make sure volume group $VG got created.
  if vg_exists "$vg_name"; then
    test_status=0
  fi

  cleanup $vg_name "$devs"
  return $test_status
}

# Create a disk with some signature, say lvm signature and make sure
# override signature can override that, wipe signature and create thin
# pool.
test_override_signatures
