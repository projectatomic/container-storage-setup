source $SRCDIR/libtest.sh

# Test that the user-specified options stored in
# EXTRA_DOCKER_STORAGE_OPTIONS actually end up in 
# the docker storage config file, appended to the variable
# DOCKER_STORAGE_OPTIONS in /etc/sysconfig/docker-storage
test_set_extra_docker_opts() {
  local devs=$TEST_DEVS
  local test_status=1
  local testname=`basename "$0"`
  local vg_name="dss-test-foo"
  local extra_options="--storage-opt dm.fs=ext4"

  # Error out if volume group $vg_name exists already
  if vg_exists "$vg_name"; then
    echo "ERROR: $testname: Volume group $vg_name already exists" >> $LOGS    
    return $test_status
  fi

  cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS="$devs"
VG=$vg_name
EXTRA_DOCKER_STORAGE_OPTIONS="$extra_options"
EOF
  
  # Run docker-storage-setup
  $DSSBIN >> $LOGS 2>&1 

  # dss failed
  if [ $? -ne 0 ]; then 
    cleanup $vg_name "$devs"
    return $test_status
  fi

  # Check if docker-storage config file was created by dss
  if [ ! -f /etc/sysconfig/docker-storage ]; then
    echo "ERROR: $testname: /etc/sysconfig/docker-storage file was not created." >> $LOGS
    cleanup $vg_name "$devs"
    return $test_status
  fi

  source /etc/sysconfig/docker-storage
  
  # Search for $extra_options in $options. 
  echo $DOCKER_STORAGE_OPTIONS | grep -q -- "$extra_options"
  
  # Successful appending to DOCKER_STORAGE_OPTIONS
  [ $? -eq 0 ] && test_status=0

  cleanup $vg_name "$devs"
  return $test_status 
}

# Test that $EXTRA_DOCKER_STORAGE_OPTIONS is successfully written
# into /etc/sysconfig/docker-storage
test_set_extra_docker_opts
