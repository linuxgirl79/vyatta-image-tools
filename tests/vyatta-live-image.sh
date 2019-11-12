#!/bin/sh
# Copyright (c) 2014 by Brocade Communications Systems, Inc.
# All rights reserved.

_create_lb3_proc_mounts ()
{
    mkdir -p "${SHUNIT_TMPDIR}"/proc
    cat > "${SHUNIT_TMPDIR}"/proc/mounts <<EOF
rootfs / rootfs rw 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
udev /dev devtmpfs rw,relatime,size=10240k,nr_inodes=504618,mode=755 0 0
devpts /dev/pts devpts rw,nosuid,noexec,relatime,gid=5,mode=620 0 0
tmpfs /run tmpfs rw,nosuid,noexec,relatime,size=405304k,mode=755 0 0
/dev/sr0 /lib/live/mount/medium iso9660 ro,noatime 0 0
/dev/loop0 /lib/live/mount/rootfs/filesystem.squashfs squashfs ro,noatime 0 0
tmpfs /lib/live/mount/overlay tmpfs rw,relatime 0 0
overlayfs / overlayfs rw,relatime,lowerdir=//filesystem.squashfs/,upperdir=/live/overlay/ 0 0
overlayfs /opt/vyatta/etc/config overlayfs rw,noatime,lowerdir=//filesystem.squashfs/,upperdir=/live/overlay/ 0 0
tmpfs /run/lock tmpfs rw,nosuid,nodev,noexec,relatime,size=5120k 0 0
tmpfs /run/shm tmpfs rw,nosuid,nodev,noexec,relatime,size=810600k 0 0
nodev /mnt/huge hugetlbfs rw,relatime 0 0
/var/run/vcfgfs.sock /opt/vyatta/config/ro 9p ro,sync,dirsync,relatime,trans=unix,version=9p2000,uname=root,dfltuid=0,dfltgid=104 0 0
EOF
}

_create_lb3_image_proc_mounts ()
{
    mkdir -p "${SHUNIT_TMPDIR}"/proc
    cat > "${SHUNIT_TMPDIR}"/proc/mounts <<EOF
rootfs / rootfs rw 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
udev /dev devtmpfs rw,relatime,size=10240k,nr_inodes=504623,mode=755 0 0
devpts /dev/pts devpts rw,nosuid,noexec,relatime,gid=5,mode=620 0 0
tmpfs /run tmpfs rw,nosuid,nodev,noexec,relatime,size=405304k,mode=755 0 0
/dev/vda1 /lib/live/mount/persistence/vda1 ext4 rw,noatime,data=ordered 0 0
/dev/loop0 /lib/live/mount/rootfs/999.mk.livecdrefactoring.09121125.squashfs squashfs ro,noatime 0 0
tmpfs /lib/live/mount/overlay tmpfs rw,relatime 0 0
overlayfs / overlayfs rw,relatime,lowerdir=/live/rootfs/999.mk.livecdrefactoring.09121125.squashfs/,upperdir=/live/persistence/vda1/boot/999.mk.livecdrefactoring.09121125/persistence 0 0
overlayfs /opt/vyatta/etc/config overlayfs rw,noatime,lowerdir=/live/rootfs/999.mk.livecdrefactoring.09121125.squashfs/,upperdir=/live/persistence/vda1/boot/999.mk.livecdrefactoring.09121125/persistence 0 0
tmpfs /run/lock tmpfs rw,nosuid,nodev,noexec,relatime,size=5120k 0 0
tmpfs /run/shm tmpfs rw,nosuid,nodev,noexec,relatime,size=810600k 0 0
nodev /mnt/huge hugetlbfs rw,relatime 0 0
/var/run/vcfgfs.sock /opt/vyatta/config/ro 9p ro,sync,dirsync,relatime,trans=unix,version=9p2000,uname=root,dfltuid=0,dfltgid=104 0 0
/dev/vda1 /boot ext4 rw,noatime,data=ordered 0 0
/dev/vda1 /boot/grub ext4 rw,noatime,data=ordered 0 0
EOF
}

_create_lb2_proc_mounts ()
{
    mkdir -p "${SHUNIT_TMPDIR}"/proc
    cat > "${SHUNIT_TMPDIR}"/proc/mounts <<EOF
rootfs / rootfs rw 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
udev /dev devtmpfs rw,relatime,size=2017460k,nr_inodes=504365,mode=755 0 0
devpts /dev/pts devpts rw,nosuid,noexec,relatime,gid=5,mode=620 0 0
/dev/sr0 /live/image iso9660 ro,noatime 0 0
/dev/loop0 /filesystem.squashfs squashfs ro,noatime 0 0
tmpfs /live/cow tmpfs rw,noatime,mode=755 0 0
overlayfs / overlayfs rw,relatime,lowerdir=//filesystem.squashfs,upperdir=/cow 0 0
tmpfs /live tmpfs rw,relatime 0 0
tmpfs /tmp tmpfs rw,nosuid,nodev,relatime 0 0
tmpfs /opt/vyatta/etc/config tmpfs rw,noatime,mode=755 0 0
tmpfs /lib/init/rw tmpfs rw,nosuid,relatime,mode=755 0 0
tmpfs /dev/shm tmpfs rw,nosuid,nodev,relatime 0 0
/var/run/vcfgfs.sock /opt/vyatta/config/ro 9p ro,sync,dirsync,relatime,trans=unix,version=9p2000,uname=root,dfltuid=0,dfltgid=104 0 0
tmpfs /config tmpfs rw,noatime,mode=755 0 0
EOF
}

_create_lb2_image_proc_mounts ()
{
    mkdir -p "${SHUNIT_TMPDIR}"/proc
    cat > "${SHUNIT_TMPDIR}"/proc/mounts <<EOF
rootfs / rootfs rw 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
udev /dev devtmpfs rw,relatime,size=2017464k,nr_inodes=504366,mode=755 0 0
devpts /dev/pts devpts rw,nosuid,noexec,relatime,gid=5,mode=620 0 0
/dev/vda1 /live/image ext4 rw,relatime,data=ordered 0 0
/dev/loop0 /999.master.08230509.squashfs squashfs ro,noatime 0 0
/dev/vda1 /live-rw-backing ext4 rw,relatime,data=ordered 0 0
/dev/vda1 /live/cow ext4 rw,relatime,data=ordered 0 0
overlayfs / overlayfs rw,relatime,lowerdir=//999.master.08230509.squashfs,upperdir=/cow 0 0
tmpfs /live tmpfs rw,relatime 0 0
tmpfs /tmp tmpfs rw,nosuid,nodev,relatime 0 0
/dev/vda1 /opt/vyatta/etc/config ext4 rw,relatime,data=ordered 0 0
tmpfs /lib/init/rw tmpfs rw,nosuid,relatime,mode=755 0 0
tmpfs /dev/shm tmpfs rw,nosuid,nodev,relatime 0 0
tmpfs /var/run tmpfs rw,nosuid,nodev,relatime 0 0
nodev /mnt/huge hugetlbfs rw,relatime 0 0
/var/run/vcfgfs.sock /opt/vyatta/config/ro 9p ro,sync,dirsync,relatime,trans=unix,version=9p2000,uname=root,dfltuid=0,dfltgid=104 0 0
/dev/vda1 /config ext4 rw,relatime,data=ordered 0 0
/dev/vda1 /boot ext4 rw,relatime,data=ordered 0 0
/dev/vda1 /boot/grub ext4 rw,relatime,data=ordered 0 0
EOF
}

testWhatIsMountedOn ()
{
    assertNull "Missing argument should return empty string" "$(vyatta-live-image what_is_mounted_on)"

    _create_lb3_proc_mounts
    assertEquals 2 "$(vyatta-live-image what_is_mounted_on / | wc -l)"
    assertEquals /dev/loop0 "$(vyatta-live-image what_is_mounted_on /lib/live/mount/rootfs.*)"

    _create_lb2_proc_mounts
    assertEquals 2 "$(vyatta-live-image what_is_mounted_on / | wc -l)"
    assertEquals /dev/sr0 "$(vyatta-live-image what_is_mounted_on /live/image.*)"
}

testGetLiveRootfsPath ()
{
    _create_lb3_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /lib/live/mount/medium/live/filesystem.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/lib/live/mount/medium
    assertEquals /lib/live/mount/medium "$(vyatta-live-image get_live_rootfs_path)"

    _create_lb3_image_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /lib/live/mount/persistence/vda1/boot/999.mk.livecdrefactoring.09121125/999.mk.livecdrefactoring.09121125.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/lib/live/mount/persistence/vda1
    assertEquals /lib/live/mount/persistence/vda1 "$(vyatta-live-image get_live_rootfs_path)"

    _create_lb2_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /live/image/live/filesystem.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/live/image
    assertEquals /live/image "$(vyatta-live-image get_live_rootfs_path)"

    _create_lb2_image_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /live/image/boot/999.master.08230509/999.master.08230509.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/live/image
    assertEquals /live/image "$(vyatta-live-image get_live_rootfs_path)"
}

testGetImagePersistencePathFromRootfs()
{
    assertEquals "RETURN: 1" "$(vyatta-live-image get_image_persistence_path_from_rootfs || echo "RETURN: $?")"
    assertEquals "RETURN: 1" "$(vyatta-live-image get_image_persistence_path_from_rootfs rootfs-is-missing || echo "RETURN: $?")"

    # create mock mountpoint
    local MP="${SHUNIT_TMPDIR}"/mnt
    mkdir -p "${MP}"
    assertEquals "RETURN: 1" "$(vyatta-live-image get_image_persistence_path_from_rootfs it-does-not-exists ${MP} || echo "RETURN: $?")"

    # if persistence directory is missing return with default label
    mkdir -p "${MP}"/boot/999.mk.livecdrefactoring.09121125
    assertEquals "RETURN: 1" "$(vyatta-live-image get_image_persistence_path_from_rootfs 999.mk.livecdrefactoring.09121125 ${MP} || echo "RETURN: $?")"

    mkdir -p "${MP}"/boot/999.mk.livecdrefactoring.09121125/persistence
    assertEquals "/boot/999.mk.livecdrefactoring.09121125/persistence" "$(vyatta-live-image get_image_persistence_path_from_rootfs 999.mk.livecdrefactoring.09121125 ${MP})"

    # test for rw/ path
    mkdir -p "${MP}"/boot/999.mk.livecdrefactoring.09121125/persistence/rw
    assertEquals "/boot/999.mk.livecdrefactoring.09121125/persistence/rw" "$(vyatta-live-image get_image_persistence_path_from_rootfs 999.mk.livecdrefactoring.09121125 ${MP})"
}

testGetImageVersion ()
{
    _create_lb3_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /lib/live/mount/medium/live/filesystem.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/lib/live/mount/medium
    assertFalse "$(vyatta-live-image get_image_version ; echo $?)"
    assertNull "$(vyatta-live-image get_image_version)"

    _create_lb3_image_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /lib/live/mount/persistence/vda1/boot/999.mk.livecdrefactoring.09121125/999.mk.livecdrefactoring.09121125.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/lib/live/mount/persistence/vda1
    assertTrue "$(vyatta-live-image get_image_version >/dev/null; echo $?)"
    assertEquals 999.mk.livecdrefactoring.09121125 "$(vyatta-live-image get_image_version)"

    _create_lb2_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /live/image/live/filesystem.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/live/image
    assertFalse "$(vyatta-live-image get_image_version ; echo $?)"
    assertNull "$(vyatta-live-image get_image_version)"

    _create_lb2_image_proc_mounts
    mkdir -p "${SHUNIT_TMPDIR}"/sys/block/loop0/loop
    echo /live/image/boot/999.master.08230509/999.master.08230509.squashfs > "${SHUNIT_TMPDIR}"/sys/block/loop0/loop/backing_file
    mkdir -p "${SHUNIT_TMPDIR}"/live/image
    assertFalse "$(vyatta-live-image get_image_version ; echo $?)"
    assertNull "$(vyatta-live-image get_image_version)"
}

oneTimeSetUp()
{
  # make SUT visible
  PATH="$(pwd)/../scripts/:${PATH}"
  export PATH

  # the implementation knows about unittest implementation
  if [ -z "${SHUNIT_TMPDIR}" ] ; then
      SHUNIT_TMPDIR=`mktemp -d`
      trap "rm -rf ${SHUNIT_TMPDIR}" EXIT 
  fi
  export SHUNIT_TMPDIR
}

tearDown()
{
  if [ -n "${SHUNIT_TMPDIR}" ] ; then
    rm -fr "${SHUNIT_TMPDIR}/*"
  fi
}

# load and run shUnit2
[ -n "${ZSH_VERSION:-}" ] && SHUNIT_PARENT=$0
. shunit2
