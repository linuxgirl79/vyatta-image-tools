#!/usr/bin/perl -w -I ../lib

# Copyright (c) 2014-2016 by Brocade Communications Systems, Inc.
# All rights reserved.

use strict;
use warnings 'all';
use Test::More 'no_plan';  # or use Test::More 'no_plan';
use File::Path qw(make_path);
use File::Slurp;
use File::Temp qw(tempdir);

use_ok('Vyatta::Live');

# mock the /proc/mounts file being used to make this work on all platforms
our @proc_mounts = <<'EOF';
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
udev /dev devtmpfs rw,relatime,size=10240k,nr_inodes=254000,mode=755 0 0
devpts /dev/pts devpts rw,nosuid,noexec,relatime,gid=5,mode=620 0 0
tmpfs /run tmpfs rw,nosuid,relatime,size=410568k,mode=755 0 0
EOF

$ENV{'SHUNIT_TMPDIR'} = tempdir( CLEANUP => 1 );
make_path($ENV{'SHUNIT_TMPDIR'} . '/proc');
write_file( $ENV{'SHUNIT_TMPDIR'} . '/proc/mounts', @proc_mounts);

# one test to ensure that calling into the shell script works
my %paths = map { $_ => 1 } what_is_mounted_on("/proc");
is( exists($paths{'proc'}), '1', 'proc is mounted on \'/proc\'');

# Do not repeat any test that we already do in vyatta-live-image.shunit2 here
