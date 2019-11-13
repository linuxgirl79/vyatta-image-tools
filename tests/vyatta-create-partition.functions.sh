#!/bin/bash

# disk helper functions
source disk_helper.sh

#
# Tests
#

test_part_num_list ()
{
    _setup_lsblk

    # Test with default partition layout
    _setup_basic_vrouter_hdd
    output=$(part_num_list sda)
    assertEquals '1 2 3 4' "$output"
    rm -rf ${SHUNIT_TMPDIR}/dev/*

    # One more test with double digits return
    for i in $(seq 1 12); do
        _setup_partition "sda" "KNAME=sda$i"
    done
    output=$(part_num_list sda)
    assertEquals '1 2 3 4 5 6 7 8 9 10 11 12' "$output"
    rm -rf ${SHUNIT_TMPDIR}/dev/*
}

test_to_kiB () {

    # Sane input
    output=$(_to_kiB "5000MB")
    assertEquals '5120000' "$output"

    # Sane input, float
    output=$(_to_kiB "4500.11MB")
    assertEquals '4608112.64' "$output"

}

test_to_MB () {

    # Sane input
    output=$(_to_MB "4096kiB")
    assertEquals '4.00' "$output"

    # Sane input, float output
    output=$(_to_MB "62024kiB")
    assertEquals '60.57' "$output"

}

_test_first_missing_part ()
{
  _setup_parted_random 3 "$(yes "vRouter" | head -n 3)"
  output=$(first_missing_part /dev/sda)
  assertEquals '4' "$output"
  _clean_up
}

#
# Shuint stuff
#

oneTimeSetUp ()
{
    local THIS_DIR=$(cd $(dirname ${0}); pwd -P)

    # make SUT visible
    PATH="${THIS_DIR}/../scripts/:${PATH}"
    export PATH

    # the implementation knows about unittest implementation
    if [ -z "${SHUNIT_TMPDIR}" ] ; then
	SHUNIT_TMPDIR=`mktemp -d`
	trap "rm -rf ${SHUNIT_TMPDIR}" EXIT
    fi
    export SHUNIT_TMPDIR

    export INSTALL_LOG=""

    TMPDIR=${SHUNIT_TMPDIR}
    export TMPDIR

    . ${THIS_DIR}/../scripts/vyatta-create-partition.functions
}

tearDown ()
{
    # clean-up after every test
    if [ -n "${SHUNIT_TMPDIR}" ] ; then
	rm -fr "${SHUNIT_TMPDIR}/*"
    fi

    _clean_up
}


# load and run shUnit2
[ -n "${ZSH_VERSION:-}" ] && SHUNIT_PARENT=$0
. shunit2
