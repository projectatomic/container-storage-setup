#!/bin/bash

WORKDIR=$(pwd)/temp/
DSSBIN="/usr/bin/docker-storage-setup"
LOGS=$WORKDIR/logs
# Keeps track of overall pass/failure status of tests. Even if single test
# fails, PASS_STATUS will be set to 1 and returned to caller when all
# tests have run.
PASS_STATUS=0

#Helper functions

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

#Tests

check_block_devs() {
  local devs=$1

  if [ -z $devs ];then
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
  done
}

run_test () {
  testfile=$1
  source $testfile

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
SRCDIR=`dirname $0`
if [ -e $SRCDIR/dss-test-config ]; then
  source $SRCDIR/dss-test-config
fi

source $SRCDIR/libtest.sh

check_config_files
setup_workdir
setup_dss_binary
check_block_devs "$DEVS"
run_tests
exit $PASS_STATUS
