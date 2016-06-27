#!/bin/bash

WORKDIR=$(pwd)/temp/
DOCKER_METADATA_DIR=/var/lib/docker
export DSSBIN="/usr/bin/docker-storage-setup"
export LOGS=$WORKDIR/logs.txt

# Keeps track of overall pass/failure status of tests. Even if single test
# fails, PASS_STATUS will be set to 1 and returned to caller when all
# tests have run.
PASS_STATUS=0

#Helper functions

# Take care of active docker and old docker metadata
check_docker_active() {
  if systemctl -q is-active "docker.service"; then
    echo "ERROR: docker.service is currently active. Please stop docker.service before running tests." >&2
    exit 1
  fi
}

# Check metadata if using devmapper
check_metadata() {
  local docker_devmapper_meta_dir="$DOCKER_METADATA_DIR/devicemapper/metadata/"
  
  [ ! -d "$docker_devmapper_meta_dir" ] && return 0

  echo "ERROR: /var/lib/docker directory exists and contains old metadata. Remove it." >&2
  exit 1
}

setup_workdir() {
  mkdir -p $WORKDIR
  rm -f $LOGS
}

# If config file is present, error out
check_config_files() {
  if [ -f /etc/sysconfig/docker-storage-setup ];then
    echo "ERROR: /etc/sysconfig/docker-storage-setup already exists. Remove it." >&2
    exit 1
  fi

  if [ -f /etc/sysconfig/docker-storage ];then
    echo "ERROR: /etc/sysconfig/docker-storage already exists. Remove it." >&2
    exit 1
  fi
}

setup_dss_binary() {
  # One can setup environment variable DOCKER_STORAGE_SETUP to override
  # which binary is used for tests.
  if [ -n "$DOCKER_STORAGE_SETUP" ];then
    if [ ! -f "$DOCKER_STORAGE_SETUP" ];then
      echo "Error: Executable $DOCKER_STORAGE_SETUP does not exist"
      exit 1
    fi

    if [ ! -x "$DOCKER_STORAGE_SETUP" ];then
      echo "Error: Executable $DOCKER_STORAGE_SETUP does not have execute permissions."
      exit 1
    fi
    DSSBIN=$DOCKER_STORAGE_SETUP
  fi
  echo "INFO: Using $DSSBIN for running tests."
}

# If disk already has signatures, error out. It should be a clean disk.
check_disk_signatures() {
  local bdev=$1
  local sig

  if ! sig=$(wipefs -p $bdev); then
    echo "ERROR: Failed to check signatures on device $bdev" >&2
    exit 1
  fi

  [ "$sig" == "" ] && return 0

  while IFS=, read offset uuid label type; do
    [ "$offset" == "# offset" ] && continue

    echo "ERROR: Found $type signature on device ${bdev} at offset ${offset}. Wipe signatures using wipefs and retry."
    exit 1
  done <<< "$sig"
}

#Tests

check_block_devs() {
  local devs=$1

  if [ -z "$devs" ];then
    echo "ERROR: A block device need to be specified for testing in dss-test-config file."
    exit 1
  fi

  for dev in $devs; do
    if [ ! -b $dev ];then
      echo "ERROR: $dev is not a valid block device."
      exit 1
    fi

    # Make sure device is not a partition.
    if [[ $dev =~ .*[0-9]$ ]]; then
      echo "ERROR: Partition specification unsupported at this time."
      exit 1
    fi

    check_disk_signatures $dev
  done
}

run_test () {
  testfile=$1

  echo "Running test $testfile" >> $LOGS 2>&1
  bash -c $testfile

  if [ $? -eq 0 ];then
    echo "PASS: $(basename $testfile)"
  else
    echo "FAIL: $(basename $testfile)"
    PASS_STATUS=1
  fi
}

run_tests() {
  local files="$SRCDIR/[0-9][0-9][0-9]-test-*"
  for t in $files;do
    run_test $t
  done
}

#Main Script

# Source config file
export SRCDIR=`dirname $0`
if [ -e $SRCDIR/dss-test-config ]; then
  source $SRCDIR/dss-test-config
  # DEVS is used by dss as well. So exporting this can fail any tests which
  # don't want to use DEVS. So export TEST_DEVS instead.
  TEST_DEVS=$DEVS
  export TEST_DEVS
fi

source $SRCDIR/libtest.sh

check_docker_active
check_metadata
check_config_files
setup_workdir
setup_dss_binary
check_block_devs "$DEVS"
run_tests
exit $PASS_STATUS
