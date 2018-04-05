source $SRCDIR/libtest.sh

# Test GPT partition table gets created for disks bigger than 2TB.
test_gpt() {
  local lbdevice tmpfile part_type
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"

  # Error out if any pre-existing volume group vg named css-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create loopback device.
   tmpfile=$(mktemp /tmp/c-s-s.XXXXXX)
   truncate --size=3T $tmpfile
   lbdevice=$(losetup -f)
   losetup --partscan $lbdevice $tmpfile

  # Create config file
  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$lbdevice"
VG=$vg_name
EOF

 # Run container-storage-setup
 $CSSBIN >> $LOGS 2>&1

 # Test failed.
 if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $CSSBIN failed." >> $LOGS
    cleanup $vg_name "$lbdevice"
    cleanup_loop_device "$tmpfile" "$lbdevice"
    return $test_status
 fi

  # Make sure volume group $VG got created
  if ! vg_exists "$vg_name"; then
    echo "ERROR: $testname: $CSSBIN failed. $vg_name was not created." >> $LOGS
  fi

  # Make sure partition table type is gpt.
  part_type=`fdisk -l "${lbdevice}" | grep "label type" | cut -d ":" -f2`
  # Get rid of blanks
  part_type=${part_type/ /}

  if [ "$part_type" == "gpt" ]; then
    test_status=0
  else
    echo "ERROR: $testname: $CSSBIN failed. Partition table type created is "$part_type", expected gpt." >> $LOGS
  fi

  cleanup $vg_name "$lbdevice"
  cleanup_loop_device "$tmpfile" "$lbdevice"
  return $test_status
}

cleanup_loop_device() {
  local tmpfile=$1
  local lbdevice=$2
  losetup -d $lbdevice
  rm $tmpfile > /dev/null 2>&1
}

test_gpt
