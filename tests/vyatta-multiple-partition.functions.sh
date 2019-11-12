#!/bin/bash

#
# Helper functions for unit tests
#

_setup_fdisk ()
{
  local arr=( $@ )

  cat > ${SHUNIT_TMPDIR}/fdisk <<EOF
Disk /dev/sda: 232.9 GiB, 250059350016 bytes, 488397168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: dos
Disk identifier: 0x75f2358b

Device     Boot  Start       End   Sectors   Size Id Type
EOF
  for i in `seq 1 ${arr[0]}`; do
    echo >> ${SHUNIT_TMPDIR}/fdisk "/dev/sda$i  *      2048    499711    497664   243M 83 ${arr[$i]}"
  done
  echo >> ${SHUNIT_TMPDIR}/fdisk ""

  function fdisk () {
    cat ${SHUNIT_TMPDIR}/fdisk
  }
}

_setup_fdisk_random ()
{ local arr=( $@ )

  cat > ${SHUNIT_TMPDIR}/fdisk <<EOF
Disk /dev/sda: 232.9 GiB, 250059350016 bytes, 488397168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: dos
Disk identifier: 0x75f2358b

Device     Boot  Start       End   Sectors   Size Id Type
EOF
  for i,j in `seq 1 ${arr[0]}` {1 2 3 5}; do
    echo >> ${SHUNIT_TMPDIR}/fdisk "/dev/sda$j  *      2048    499711    497664   243M 83 ${arr[$i]}"
  done
  echo >> ${SHUNIT_TMPDIR}/fdisk ""

  function fdisk () {
    cat ${SHUNIT_TMPDIR}/fdisk
  }
}
_setup_e2label ()
{
  local arr=( $@ )
  mkdir -p ${SHUNIT_TMPDIR}/dev
  for i in `seq 0 $(expr ${#arr[@]} - 1)`; do
    echo ${arr[$i]} > ${SHUNIT_TMPDIR}/dev/sda$(expr $i + 1)
  done

  function e2label () {
    cat ${SHUNIT_TMPDIR}$1
  }
}

_clean_up ()
{
  unset -f fdisk
  unset -f e2label
}


#
# Tests
#

test__add_part ()
{
  VII_PART_LIST="vRouter 1024 / LIBVIRT 2048 /var/lib/libvirt/images"
  LIST=$(_add_part ${VII_PART_LIST[@]} "part3" "4096" "/mnt/part3")
  assertEquals "vRouter 1024 / LIBVIRT 2048 /var/lib/libvirt/images part3 4096 /mnt/part3" "$LIST"

  # I.e. no added whitespaces
  VII_PART_LIST=""
  LIST=$(_add_part ${VII_PART_LIST[@]} "part3" "4096" "/mnt/part3")
  assertEquals "part3 4096 /mnt/part3" "$LIST"
}

test__rm_part ()
{
  # Remove last in a list
  VII_PART_LIST="vRouter 1024 / LIBVIRT 2048 /var/lib/libvirt/images"
  LIST=$(_rm_part ${VII_PART_LIST[@]})
  assertEquals "vRouter 1024 /" "$LIST"
}

test__adjust_sizes ()
{
  # 1 extra partition
  VII_PART_LIST="vRouter 1024 / LIBVIRT 2048 /var/lib/libvirt/images"
  LIST=$(_adjust_sizes 500 ${VII_PART_LIST})
  assertEquals "vRouter 500 / LIBVIRT 500 /var/lib/libvirt/images" "$LIST"

  # 3 extra partitions
  VII_PART_LIST="vRouter 1024 / part0 100 /mnt/part0 part1 200 /mnt/part1 part2 300 /mnt/part2"
  LIST=$(_adjust_sizes 999 ${VII_PART_LIST})
  assertEquals "vRouter 999 / part0 999 /mnt/part0 part1 999 /mnt/part1 part2 999 /mnt/part2"
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

    . ${THIS_DIR}/../scripts/vyatta-multiple-partition.functions
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
