#!/usr/bin/perl
# SPDX-License-Identifier: GPL-2.0-only

# **** License ****
#
# Copyright (c) 2017-2019, AT&T Intellectual Property.
# All Rights Reserved.
#
# Copyright (c) 2014-2017 by Brocade Communications Systems, Inc.
# All rights reserved.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2010-2013 Vyatta, Inc.
# All Rights Reserved.
#
# Description: Script to re-name a system image.
#
# **** End License ****

use strict;
use warnings;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use Sys::Syslog qw/:standard :macros/;

use lib "/opt/vyatta/share/perl5/";
use Vyatta::Live;

my $live_image_root = get_live_image_root();
my $UNION_BOOT = "$live_image_root/boot";
my $XEN_DEFAULT_IMAGE = "$UNION_BOOT/%%default_image";

my $old_name;
my $new_name;

GetOptions(
    'old_name:s' => \$old_name,
    'new_name:s' => \$new_name,
    );
    
if (!defined($old_name) || !defined($new_name)) {
    printf("Must specify both old and new name.\n");
    exit 1;
}

my $image_path = "$live_image_root/boot";

if (! -e "$image_path") {
    # must be running on old non-image installed system
    $image_path = "";
}

if (! -e "$image_path/$old_name") {
    printf("Old name $old_name does not exist.\n");
    exit 1;
}

if (("$new_name" eq "Old-non-image-installation") ||
    ("$new_name" eq "grub") ||
    ("$new_name" =~ /^initrd/) ||
    ("$new_name" =~ /^vmlinuz/) ||
    ("$new_name" =~ /^System\.map/) ||
    ("$new_name" =~ /^config-/) ||
    ("$new_name" =~ /^%%/)) {
    printf("Can't use reserved image name.\n");
    exit 1;
}

my $cmdline=`cat /proc/cmdline`;
my $cur_name;
($cur_name, undef) = split(' ', $cmdline);
if ($cur_name =~ s/BOOT_IMAGE=\/boot\///) {
    $cur_name =~ s/\/vmlinuz.*//;
} else {
    # Boot command line is not formatted as it would be for a system
    # booted via grub2 with union mounted root filesystem.  Another
    # possibility is that it the system is Xen booted via pygrub.
    #
    if (-l $XEN_DEFAULT_IMAGE) {
	# On Xen/pygrub systems, we figure out the running version by
	# looking at the bind mount of /boot.
	$cur_name = `mount | awk '/on \\/boot / { print \$1 }'`;
	$cur_name =~ s?$live_image_root/boot/??;
	chomp($cur_name);
    }
}

if ($old_name eq $cur_name) {
    printf("Can't re-name the running image.\n");
    exit 1;
}

if (-e "$image_path/$new_name") {
    printf("New name $new_name already exists.\n");
    exit 1;
}

printf("Renaming image $old_name to $new_name.\n");

my $tmpfh;
my $tmpfilename;
($tmpfh, $tmpfilename) = tempfile();

open (my $grubfh, '<', "${image_path}/grub/grub.cfg")
    or die "Can't open grub file.\n";

# This is sensitive to the format of menu entries and boot paths
# in the grub config file.
#
# NB: The configuration recovery option was added after the other standard
#     GRUB menu entries so that when installing images with this option from
#     older images, they aren't able to modify the GRUB template to insert
#     the image name.  So, the template uses 'for above image' instead of
#     '@@IMAGE_NAME@@' so it looks ok!  This is replaced when installed from
#     newer images but not from older ones, hence the need to deal with both
#     options below.
#
my $line;

# old_name is likely to have regexp special characters in it
my $safe_old_name = quotemeta($old_name);
while ($line = <$grubfh>) {
    $line =~ s/\/boot\/$safe_old_name\//\/boot\/$new_name\//g;
    $line =~ s/\/boot\/$safe_old_name /\/boot\/$new_name /g;
    $line =~ s/Vyatta $safe_old_name /Vyatta $new_name /;
    $line =~ s/Vyatta image $safe_old_name /Vyatta image $new_name /;
    $line =~ s/Lost password change $safe_old_name /Lost password change $new_name /;
    $line =~ s/Configuration Recovery $safe_old_name /Configuration Recovery $new_name /;
    $line =~ s/Configuration Recovery for above image /Configuration Recovery $new_name /;
    printf($tmpfh $line);
}

close($tmpfh) or die "Close temp grub file failed: $!\n";
close($grubfh);

move("$image_path/$old_name", "$image_path/$new_name")
    or die "rename $old_name to $new_name failed: $!\n";

copy($tmpfilename, "$image_path/grub/grub.cfg")
    or die "copy $tmpfilename to grub.cfg failed: $!\n";

syslog("warning", "System image $old_name has been renamed $new_name");

printf("Done.\n");
