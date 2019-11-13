#!/usr/bin/perl
# SPDX-License-Identifier: GPL-2.0-only

#
# Clone-image.pl: A script to clone a local or remote system image.
#
# Copyright (C) 2010 Vyatta, Inc.
# All Rights Reserved.
#
# Copyright (c) 2014-2017 by Brocade Communications Systems, Inc.
# All rights reserved.
#
# Copyright (C) 2017-2019 AT&T Intellectual Property.
# All Rights Reserved.
#
# This script makes an identical copy -- a "clone" -- of a system
# image that is already installed on the local machine or a remote
# machine, and updates the grub configuration file to make it
# bootable.
#
# Note that if a full clone (i.e. one that includes the persistent
# portion of the image) is made of a remote image, the clone will have
# the remote machine's config.boot.  The interface section will
# typically include the MAC addresses of the remote machines, which
# will not be valid on the local machine.  The config.boot file
# may need to be edited before it can be used on the local machine.
#
# Command line options:
#
#  --old_name <image-name>     Name of image to clone. Can be the name of
#                              an image on the local machine, or have the
#                              form: <user>@<hostname>:<image-name>.
#                              Required.
#
#  --new_name <image-name>     What to name the clone. Required.
#
#  --no_rw                     Don't copy the persistent portion of the image.
#                              This leaves the clone in roughly the same
#                              state as a freshly installed system.
#                              Optional.
#
# This script must be run as root.
#

use strict;
use warnings;
use Cwd;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Path;
use IPC::Run qw(run);
use Scalar::Util qw (looks_like_number);
use Term::ReadKey;
use English;
use Env;

use lib '/opt/vyatta/share/perl5';
use Vyatta::Live;
use Vyatta::RestClient;

my ( $old_name, $new_name, $remote, $no_rw, $ro_size, $rw_size );
my ( $remote_host, $remote_user, $remote_passwd );
my ( $cli, $err_code, $err, $output );
my $image_path  = get_live_image_root() . '/boot';
my $persistence = get_persistence_label();

GetOptions(
    'old_name:s' => \$old_name,
    'new_name:s' => \$new_name,
    'no_rw'      => \$no_rw,
);

#
# Print an error message and exit
#
sub err_exit {
    my ($str) = @_;

    printf("$str\n");
    exit 1;
}

#
# Delete any remains of the clone, then print an error message and exit.
#
sub err_exit_cleanup {
    my ($str) = @_;
    run( [ 'rm', '-rf', "$image_path/$new_name" ] );
    err_exit($str);
}

#
# run and process a commands output though a sub-ref and return then result
#
sub run_filter {
    my ( $cmd, $filter, $ignore ) = @_;
    my $cmd_out;
    my $result = run( $cmd, \undef, \$cmd_out );
    if ( !$result ) {
        return if $ignore;
        err_exit( "failed to run cmd " . join( ' ', @$cmd ) );
    }
    return $filter->($cmd_out);
}

#
# Use the Vyatta remote API to get the size of a remote image and
# its persistent portion.
#
sub get_remote_size {

    # Format of $remote is: user@hostname
    if ( $remote =~ m/(.*)@(.*)/ ) {
        $remote_user = $1;
        $remote_host = $2;
    }

    if ( !defined($remote_user) ) {
        err_exit("Can't parse $remote");
    }

    printf("Checking size of remote image $old_name.\n");

    ( $err_code, $err ) = $cli->test_connectivity( $remote_host, 1 );
    if ( defined($err) ) {
        printf("Connection failed: $err\n");
        if ( $err_code == 500 ) {
            printf(
"Make sure the remote router is up, is reachable, and has the Vyatta\n"
            );
            printf("remote management service enabled.\n");
        }
        exit 1;
    }

    printf("Password for $remote_user\@$remote_host: ");
    ReadMode 'noecho';
    $remote_passwd = <STDIN>;
    ReadMode 'restore';
    printf("\n");
    chomp($remote_passwd);

    ( $err_code, $err ) =
      $cli->auth( $remote_host, $remote_user, $remote_passwd );
    !defined($err)
      or err_exit("Authentication failed: $err");

    ( $err, $output ) = $cli->run_op_cmd("show system image storage");
    !defined($err)
      or err_exit("Command failed: $err");

    my @out_lines = split( /\n/, $output );
    foreach my $line (@out_lines) {
        if ( $line =~ m/($old_name)\s+(\d+)\s+(\d+)/ ) {
            return ( $2, $3 );
        }
    }
    err_exit("Remote image $old_name not found");
}

#
# Copy a local or remote image into the image directory on the local system,
# using the image name provided by the user.
#
sub copy_image {
    my ( $old_path, $new_path );
    my @find_expr;
    my $cmd;
    my @port_arg;
    my ( $err1, $err2 );
    my $result;

    $old_path = "$image_path/$old_name";
    $new_path = "$image_path/$new_name";

    if ( defined($remote) ) {
        $cli->configure();
        my @ssh_params;
        my $ssh_port;
        ( $err1, @ssh_params ) = $cli->configure_show('service ssh port');
        ( $err2, $ssh_port )   = $cli->configure_show('service ssh port');
        $cli->configure_exit();
        if ( defined($err1) || defined($err2) ) {
            err_exit("Can't open SSH connection to $remote: $err1 $err2\n");
        }
        if ( !(@ssh_params) ) {
            err_exit("Error: SSH is not configured on remote system.\n");
        }
        if ( defined($ssh_port) && $ssh_port != 22 ) {
            @port_arg = ( '-p', $ssh_port );
        }
    }

    if ( defined($no_rw) ) {
        @find_expr =
          ( qw(find . -path), "./$persistence", qw(-prune -o -print0) );
    } else {
        @find_expr = qw(find . -print0);
    }
    run( [ 'mkdir', $new_path ] );
    if ( !-d $new_path ) {
        err_exit("Unable to create directory: $new_path");
    }

    if ( defined($remote) ) {
        printf("Copying remote image $old_name to $new_name...\n");
        my $find_str = join( ' ', ( map { qq('$_') } @find_expr ) );
        my $remote_cmd = "cd '$old_path' ; $find_str | cpio -o0";
        $result = run( [ 'ssh', @port_arg, $remote, $remote_cmd ],
            '|', [ 'cpio', '-D', $new_path, '-i' ] );
    } else {
        printf("Copying local image $old_name to $new_name...\n");
        my $cwd = cwd();
        chdir($old_path);
        $result = run( \@find_expr, '|', [ 'cpio', '-0pd', $new_path ] );
        chdir($cwd);
    }
    if ( !$result ) {

        # Cleanup
        err_exit_cleanup("Unable to copy remote image to local system");
    }
    if ( defined($no_rw) ) {
        $result = run( [ 'mkdir', "$new_path/$persistence" ] );
        if ( !$result ) {

            # Cleanup
            err_exit_cleanup("Unable to create $new_path/$persistence");
        }
    }
}

#
# Main
#

( $EUID == 0 )
  or err_exit "This program must be run by root.";

if ( !defined($old_name) || !defined($new_name) ) {
    err_exit "Must specify both old and new name.";
}

if ( !-e "$image_path" ) {

    # must be running on old non-image installed system
    $image_path = "";
}

if ( $old_name =~ m/(.*@.*):(.*)/ ) {
    $remote   = $1;
    $old_name = $2;
}

if ( !defined($remote) && !-e "$image_path/$old_name" ) {
    err_exit "Old name $old_name does not exist.\n";
}

if (   ( "$new_name" eq "Old-non-image-installation" )
    || ( "$new_name" eq "grub" )
    || ( "$new_name" =~ /^initrd/ )
    || ( "$new_name" =~ /^vmlinuz/ )
    || ( "$new_name" =~ /^System\.map/ )
    || ( "$new_name" =~ /^config-/ )
    || ( "$new_name" =~ /^%%/ ) )
{
    err_exit "Can't use reserved image name.";
}

if ( -e "$image_path/$new_name" ) {
    err_exit "New name $new_name already exists.";
}

# Check disk space
my $space_avail = run_filter(
    [ 'df', '-k', '--output=avail', $image_path ],
    sub { return ( split( '\n', $_[0] ) )[-1]; }
);

my $space_needed;
if ( defined($remote) ) {
    $cli = RestClient->new();
    ( $ro_size, $rw_size ) = get_remote_size($remote);
    defined($ro_size) && defined($rw_size)
      or err_exit("Unable to determine size of remote image $old_name");
} else {
    my $du_filter = sub { return ( split( ' ', $_[0] ) )[0]; };
    $ro_size =
      run_filter( [ 'du', '-s', "$image_path/$old_name" ], $du_filter );
    $rw_size = run_filter( [ 'du', '-s', "$image_path/$old_name/$persistence" ],
        $du_filter );
    if ( !looks_like_number($ro_size) || !looks_like_number($rw_size) ) {
        err_exit("Unable to determine disk space for $image_path/$old_name\n");
    }
    $ro_size -= $rw_size;
}

if ( defined($no_rw) ) {
    $space_needed = $ro_size;
} else {
    $space_needed = $ro_size + $rw_size;
}

if ( $space_avail <= $space_needed ) {
    printf("Not enough space to store cloned image.\n");
    printf("Need $space_needed MB, but only have $space_avail MB.\n");
    exit(1);
}

copy_image();

printf("Setting up grub file...\n");

my $grubfile = "${image_path}/grub/grub.cfg";
my $grubfh;

run( [ "$vyatta_sbindir/vyatta_update_grub.pl", "--generate-grub=$new_name" ] );

if ( defined($remote) ) {

    # Restore the use@hostname format
    $old_name = "$remote$old_name";
}

my $message = "New system image $new_name has been cloned from $old_name";
if ( defined($no_rw) ) {
    $message .= " without read-write directory.";
} else {
    $message .= " with read-write directory.";
}
run( [ 'logger', '-p', 'local3.warning', '-t', 'SystemImage', $message ] );

printf("Done.\n");

