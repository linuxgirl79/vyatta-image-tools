#!/bin/bash

testRun ()
{
    # succeed (don't run) if unconfigured
    TEXT=$(VII_PREINSTALL_VIRTUALIZATION='false' 10-virtualization run)
    assertTrue "Returns true" $?
    assertEquals "" "${TEXT}"

    # fail if missing arguments
    TEXT=$(VII_PREINSTALL_VIRTUALIZATION='true' 10-virtualization run 2>/dev/null)
    assertFalse "Returns false" $?
    #assertEquals "" "${TEXT}"
}

oneTimeSetUp ()
{
    local THIS_DIR=$(cd $(dirname ${0}); pwd -P)

    vyatta_sbindir="${THIS_DIR}/../scripts"
    export vyatta_sbindir

    # make SUT visible
    PATH="${THIS_DIR}/../preinstall.d:${PATH}"
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
}

tearDown ()
{
    # clean-up after every test
    if [ -n "${SHUNIT_TMPDIR}" ] ; then
	rm -fr "${SHUNIT_TMPDIR}/*"
    fi
}

# load and run shUnit2
[ -n "${ZSH_VERSION:-}" ] && SHUNIT_PARENT=$0
. shunit2
