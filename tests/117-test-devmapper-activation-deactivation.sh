source $SRCDIR/libtest.sh

test_devmapper_deactivation_activation() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="css-test-foo"
  local infile=${WORKDIR}/container-storage-setup
  local outfile=${WORKDIR}/container-storage

  # Error out if any pre-existing volume group vg named css-test-foo
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists." >> $LOGS
    return $test_status
  fi

  # Create config file
  cat << EOF > $infile
DEVS="$devs"
VG=$vg_name
CONTAINER_THINPOOL=container-thinpool
EOF

  local create_cmd="$CSSBIN create -o $outfile $CSS_TEST_CONFIG $infile"
  local deactivate_cmd="$CSSBIN deactivate $CSS_TEST_CONFIG"
  local activate_cmd="$CSSBIN activate $CSS_TEST_CONFIG"
  local list_cmd="$CSSBIN list $CSS_TEST_CONFIG"
  local config_status

  # Run container-storage-setup
  $create_cmd >> $LOGS 2>&1

  # Test failed.
  if [ $? -ne 0 ]; then
    echo "ERROR: $testname: $create_cmd failed." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Make sure volume group $VG got created
  if ! vg_exists "$vg_name"; then
    echo "ERROR: $testname: create operation failed. Volume group $vg_name was not created." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Make sure thinpool got created
  if ! lv_exists "$vg_name" "container-thinpool";then
    echo "ERROR: $testname: create operation failed. Thinpool container-thinpool was not created." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Deactivate storage config
  if ! $deactivate_cmd >> $LOGS 2>&1; then
    echo "ERROR: $testname: $deactivate_cmd failed." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Make sure config state changed to inactive.
  config_status=`$list_cmd | grep "Status:" | cut -d " " -f2`
  if [ "$config_status" != "inactive" ]; then
    echo "error: $testname: configuration status is $config_status. It should be inactive after deactivation." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi


  # Make sure thinpool lv got deactivated.
  if lv_is_active "$vg_name" "container-thinpool";then
    echo "ERROR: $testname: deactivate operation failed. Volume $vg_name/container-thinpool is still active" >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Activate storage config
  if ! $activate_cmd >> $LOGS 2>&1; then
    echo "ERROR: $testname: $activate_cmd failed." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Make sure config state changed to active.
  config_status=`$list_cmd | grep "Status:" | cut -d " " -f2`
  if [ "$config_status" != "active" ]; then
    echo "error: $testname: configuration status is $config_status. It should be active after activation." >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  # Make sure thinpool lv got activated.
  if ! lv_is_active "$vg_name" "container-thinpool";then
    echo "ERROR: $testname: activate operation failed. Volume $vg_name/container-thinpool is not active" >> $LOGS
    cleanup $vg_name "$devs" "$infile" "$outfile"
    return $test_status
  fi

  test_status=0
  cleanup $vg_name "$devs" "$infile" "$outfile"
  return $test_status
}

# Test if deactivation/activation works with storage driver devmapper
test_devmapper_deactivation_activation
