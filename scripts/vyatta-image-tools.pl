#!/usr/bin/perl -w
# SPDX-License-Identifier: GPL-2.0-only

# Copyright (c) 2017-2019, AT&T Intellectual Property.
# All Rights Reserved.

# Copyright (c) 2014-2017 by Brocade Communications Systems, Inc.
# All rights reserved.

use Getopt::Long;
use lib "/opt/vyatta/share/perl5/";

use strict;
use IO::Prompt;
use File::Slurp qw(read_file);

use Vyatta::Configd;
use Vyatta::Live;
use IPC::Run3;

my ( $show, $delete, $updateone );
my $check = 1;
my @copy;
my @update;
my $live_image_root = get_live_image_root();
my $u               = '';
my $p               = '';
my $si              = '';
$u  = $ENV{VY_COPY_USER}       if defined $ENV{VY_COPY_USER};
$p  = $ENV{VY_COPY_PASS}       if defined $ENV{VY_COPY_PASS};
$si = $ENV{VY_COPY_SOURCEINTF} if defined $ENV{VY_COPY_SOURCEINTF};

use constant {
    DOWNLOAD => 0,
    UPLOAD   => 1,
};
my $VYATTA_SHARED_STORAGE = '/opt/vyatta/sbin/vyatta_shared_storage';

GetOptions(
    "show=s"      => \$show,
    "delete=s"    => \$delete,
    "update=s{2}" => \@update,
    "updateone=s" => \$updateone,
    "copy=s{2}"   => \@copy,
    "check"       => \$check
);

if ( defined $show ) {
    show($show);
}
if ( defined $delete ) {
    delete_file($delete);
}
if (@update) {
    update(@update);
}
if ( defined($updateone) ) {
    update( $updateone, "running" );
}
if (@copy) {

    # Per requirement, set source interface according to
    # 'security ssh-client source-interface'
    if ( !length $si ) {
        use Vyatta::Configd;
        my $client = Vyatta::Configd::Client->new();
        my $ret    = eval {
            $client->tree_get_hash("security ssh-client source-interface");
        };
        $si = $ret->{'source-interface'} if defined $ret->{'source-interface'};
    }
    copy(@copy);
}

sub check_home {
    my ($file) = @_;
    my $uid = read_file('/proc/self/loginuid');
    chomp $uid;
    my $home;
    if ($uid) {
        my @pwe = getpwuid($uid);
        $home = $pwe[7] if ( scalar(@pwe) >= 8 );
    }
    return unless defined($home) and length($home) > 1;
    return substr( $file, 0, length($home) ) eq $home;
}

sub check_file_perm {
    my ( $file, $perm ) = @_;
    return 1 unless $check;
    return 1 unless ( -x ${VYATTA_SHARED_STORAGE} );
    return 1 if check_home($file);
    my $result;
    my @cmd = (${VYATTA_SHARED_STORAGE}, '--check', ${perm}, ${file});
    run3(\@cmd, \undef, \$result);
    chomp $result;
    return 1 if ( defined($result) && $result eq "allowed" );
    print "Cannot access $file: permission denied\n";
    return;
}

sub conv_file {
    my $file   = " ";
    my $filein = pop(@_);
    $file = $filein;
    my $topdir;
    if ( $file =~ /(.+?):\/\/(.*)/ ) {
        $topdir = $1;
        $file   = $2;
    }
    elsif ( $file =~ /^\// ) {
        $topdir = "running";
    }
    else {
        print "File: $filein not found \n";
        exit 1;
    }
    if ( $topdir eq "running" ) {
        $file = "/$file";
    }
    elsif ( lc($topdir) eq 'disk-install' ) {
        $file = "$live_image_root/$file";
    }
    elsif ( lc($topdir) eq 'tftp' ) {
        $file   = $filein;
        $topdir = 'url';
    }
    elsif ( lc($topdir) eq 'http' ) {
        $file   = $filein;
        $topdir = 'url';
    }
    elsif ( lc($topdir) eq 'ftp' ) {
        $file   = $filein;
        $topdir = 'url';
    }
    elsif ( lc($topdir) eq 'scp' ) {
        $file   = $filein;
        $topdir = 'url';
    }
    elsif ( lc($topdir) eq 'sftp' ) {
        $file   = $filein;
        $topdir = 'url';
    }
    else {
        foreach (qw(live-rw persistence persistence/rw)) {
            print "$live_image_root/boot/$topdir/$_ \n";

            if ( -e "$live_image_root/boot/$topdir/$_/$file" ) {
                $file = "$live_image_root/boot/$topdir/$_/$file";
                last;
            }
        }

        if ( length $file == 0 ) {
            print "Image $topdir not found!\n";
            exit 1;
        }
    }

    # Trim extra /'s for pretty output
    $file =~ s/^\/\//\//g;
    return ( $topdir, $file );
}

sub conv_file_to_rel {
    my ( $topdir, $filename ) = @_;
    if ( $topdir eq "running" ) {
        $filename =~ s?/?$topdir://?;
    }
    elsif ( $topdir eq "disk-install" ) {
        $filename =~ s?$live_image_root/?$topdir://?;
    }
    else {
        $filename =~
s?$live_image_root/boot/$topdir/(live-rw|persistence|persistence/rw)/?$topdir://?;
    }
    return $filename;
}

sub delete_file {
    my ($file) = @_;
    ( my $topdir, $file ) = conv_file($file);
    if ( $topdir eq 'url' ) {
        print "Cannot delete files from a url\n";
        exit 1;
    }
    exit 1 unless check_file_perm( $file, 'rw' );
    if ( -d $file ) {
        my $print_dir = conv_file_to_rel( $topdir, $file );
        if ( y_or_n("Do you want to erase the entire $print_dir directory?") ) {
            system("rm -rf $file");
            print("Directory erased\n");
        }
    }
    elsif ( -f $file ) {
        my $print_file = conv_file_to_rel( $topdir, $file );
        if ( y_or_n("Do you want to erase the $print_file file?") ) {
            system("rm -rf $file");
            print("File erased\n");
        }
    }
}

sub url_copy {
    my ( $from, $to ) = @_;
    my ( $f_topdir, $t_topdir );
    ( $f_topdir, $from ) = conv_file($from);
    ( $t_topdir, $to )   = conv_file($to);
    if ( $t_topdir eq 'url' && $f_topdir eq 'url' ) {
        print "Cannot copy a url to a url\n";
        exit 1;
    }
    elsif ( $t_topdir eq 'url' ) {
        exit 1 unless check_file_perm( $from, 'r' );
        if ( -d $from ) {
            print "Cannot upload an entire directory to url\n";
            exit 1;
        }
        elsif ( $to =~ /http/ ) {
            print "Cannot upload to http url\n";
            exit 1;
        }
        curl( $from, $to, UPLOAD );
    }
    elsif ( $f_topdir eq 'url' ) {
        if ( -d $to ) {
            $from =~ /.*\/(.*)/;
            my $from_file = $1;
            $to = "$to/$from_file";
            exit 1 unless check_file_perm( $to, 'rw' );
            if ( -f "$to" ) {
                if ( !y_or_n("This file exists; overwrite if needed?") ) {
                    exit 0;
                }
            }
        }
        curl( $from, $to, DOWNLOAD );
    }
    exit 0;
}

sub copy {
    my ( $from, $to ) = @_;
    my ( $f_topdir, $t_topdir );
    ( $f_topdir, $from ) = conv_file($from);
    if ( $f_topdir eq 'url' ) {
        url_copy( $from, $to );
    }
    ( $t_topdir, $to ) = conv_file($to);
    if ( $t_topdir eq 'url' ) {
        url_copy( $from, $to );
    }
    exit 1 unless check_file_perm( $from, 'r' );
    exit 1 unless check_file_perm( $to,   'rw' );
    $from =~ /.*\/(.*)/;
    my $from_file = $1;
    if ( -d $from && -e $to && !( -d $to ) ) {
        print "Cannot copy a directory to a file.\n";
        return 1;
    }
    elsif ( -f $to || ( -d $to && -f "$to/$from_file" ) ) {
        if ( y_or_n("This file exists; overwrite if needed?") ) {
            rsync( $from, $to );
        }
    }
    elsif ( -d $to && -d $from ) {
        if ( y_or_n("This directory exists; would you like to merge?") ) {
            rsync( $from, $to );
        }
    }
    else {
        rsync( $from, $to );
    }
}

sub update {
    my ( $to, $from ) = @_;
    my ( $t_topdir, $f_topdir );
    ( $f_topdir, $from ) = conv_file("$from://");
    if ( $f_topdir eq 'url' ) {
        print "Cannot clone from a url\n";
        exit 1;
    }
    ( $t_topdir, $to ) = conv_file("$to://");
    if ( $t_topdir eq 'running' ) {
        print "Cannot clone to running\n";
        exit 1;
    }
    if ( $t_topdir eq 'disk-install' ) {
        print "Cannot clone to disk-install\n";
        exit 1;
    }
    if ( $t_topdir eq 'url' ) {
        print "Cannot clone to a url\n";
        exit 1;
    }
    my $print_from = conv_file_to_rel( $f_topdir, $from );
    my $print_to   = conv_file_to_rel( $t_topdir, $to );
    my $msg =
        "WARNING: This is a destructive copy of the /config directories\n"
      . "This will erase all data in the "
      . $print_to
      . "config directory\n"
      . "This data will be replaced with the data from "
      . $print_from
      . "config\n"
      . "The current config data will be backed up in "
      . $print_to
      . "config.preclone\n"
      . "Do you wish to continue?";
    if ( y_or_n("$msg") ) {
        system("rm -rf $to/config.preclone");
        system("mv $to/config $to/config.preclone") if ( -d "$to/config" );
        my $confdir = "config";
        $confdir = "opt/vyatta/etc/config" if ( $f_topdir eq "disk-install" );
        if ( rsync( "$from/$confdir", $to ) > 0 ) {
            print "Clone Failed!\nRestoring old config\n";
            system("mv $to/config.preclone $to/config");
        }
    }
}

sub rsync {
    my ( $from, $to ) = @_;
    system("rsync -a --progress --exclude '.wh.*' $from $to");
    return $?;
}

sub curl {
    my ( $from, $to, $direction_flag ) = @_;
    $direction_flag = DOWNLOAD unless defined $direction_flag;

    my ( @args, $stdout, $err );
    if ( $direction_flag == UPLOAD ) {
        @args = ( "curl", "-K-", "-#", "-T", $from, $to );
    } elsif ( $direction_flag == DOWNLOAD ) {
        @args = ( "curl", "-K-", "-#", "-o", $to, $from );
    }

    my $stdin = '';
    if ( length $u && length $p ) {
        $stdin = "user=\"$u:$p\"\n";
    }
    elsif ( length $u ) {
        $stdin = "user=\"$u:\"\n";
        print
"SSH public-key based authentication not yet implemented. Please provide a plaintext password.\n";
        exit 1;
    }
    if ( length $si ) {
        my $client = Vyatta::Configd::Client->new();
        die "Unable to connect to the Vyatta Configuration Daemon"
          unless defined($client);
        my $oper_state =
          $client->tree_get_full_hash("interfaces statistics interface $si");
        my @addrs = @{ $oper_state->{addresses} }
          if defined $oper_state->{addresses};
        foreach my $ip (@addrs) {
            my $address = $ip->{address};
            $address =~ s/\/.*//;
            if ( $stdin =~ /interface=/ ) {
                $stdin =~ s/interface=.*/interface=\"$address\"/;
            } else {
                $stdin .= "interface=\"$address\"\n";
            }
            print "Using source-interface address: $address\n";
            run3 \@args, \$stdin, \$stdout, \$err;
            if ( $? != 0 ) {
                print "$err";
                next;
            }
            print "Success.\n";
            return;
        }
        return;
    }
    run3 \@args, \$stdin, \$stdout, \$err;
    if ( $? != 0 ) {
        print "$err";
        return;
    }
    print "Success.\n";
}

sub y_or_n {
    my ($msg) = @_;
    my $process_client = $ENV{'VYATTA_PROCESS_CLIENT'};
    if ( defined $process_client ) {
        return 1 if ( $process_client =~ /gui2_rest/ );
    }
    print "$msg (Y/N): ";
    my $input = <>;
    return 1 if ( $input =~ /Y|y/ );
    return 0;
}

sub show {
    my ( $topdir, $file ) = conv_file( pop(@_) );
    my $output = "";
    if ( $topdir eq 'url' ) {
        print "Cannot show files from a url\n";
        exit 1;
    }
    exit 1 unless check_file_perm( $file, 'r' );
    if ( -d $file ) {
        print "########### DIRECTORY LISTING ###########\n";
        system("ls -lGph  --group-directories-first $file");
    }
    elsif ( -T $file ) {
        print "########### FILE INFO ###########\n";
        my $filename = conv_file_to_rel( $topdir, $file );
        print "File Name: $filename\n";
        print "Text File: \n";
        my $lsstr = `ls -lGh $file`;
        parsels($lsstr);
        print "  Description:\t";
        system("file -sb $file");
        print "\n########### FILE DATA ###########\n";
        system("cat $file");
    }
    elsif ( $file =~ /.*\.pcap/ ) {
        print "########### FILE INFO ###########\n";
        my $filename = conv_file_to_rel( $topdir, $file );
        print "File Name: $filename\n";
        print "Binary File: \n";
        my $lsstr = `ls -lGh $file`;
        parsels($lsstr);
        print "  Description:\t";
        system("file -sb $file");
        print "\n########### FILE DATA ###########\n";
        system("tshark -r $file | less");
    }
    elsif ( -B $file ) {
        print "########### FILE INFO ###########\n";
        my $filename = conv_file_to_rel( $topdir, $file );
        print "File Name: $filename\n";
        print "Binary File: \n";
        my $lsstr = `ls -lGh $file`;
        parsels($lsstr);
        print "  Description:\t";
        system("file -sb $file");
        print "\n########### FILE DATA ###########\n";
        system("hexdump -C $file| less");
    }
    else {
        my $filename = conv_file_to_rel( $topdir, $file );
        print "File: $filename not found\n";
    }
}

sub parsels {
    my $lsout = pop(@_);
    my @ls = split( ' ', $lsout );
    print "  Permissions: $ls[0]\n";
    print "  Owner:\t$ls[2]\n";
    print "  Size:\t\t$ls[3]\n";
    print "  Modified:\t$ls[4] $ls[5] $ls[6]\n";
}
