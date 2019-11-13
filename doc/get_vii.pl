#!/usr/bin/perl

# **** License ****
#
# Copyright (c) 2018 AT&T
#    All Rights Reserved.
#
# License:
#
# This software is licensed, and not freely redistributable. See the
# subscription license agreement for details.
#
# **** End License ****

use strict;
use warnings;

my $root = "../";

sub read_vii_database {
    open( my $fd, '<', "${root}/vii_database/vii.defaults" );
    my $vii_data = do { local $/; <$fd>; };
    close($fd);
    return $vii_data;
}

sub parse_vii {
    my ($vii_data) = @_;
    my @vii = split( "\n", $vii_data );
    my @vii_vars = ();

    foreach (@vii) {
        if (/^#/) {
            next;
        }
        if (/^: \$\{([\w]*):='?([\w]*)'?\}\s*#?\s*(.*)/) {
            my %var = (
                'var' => $1,
                'val' => $2,
                'com' => $3,
            );
            push @vii_vars, \%var;
        }
    }
    return @vii_vars;
}

sub append_man {
    my ($vii) = @_;
    open( my $fh, '>>', 'vyatta-autoinstall.7.md' );
    foreach (@$vii) {
        print $fh " * `$_->{'var'}`:\n";
        print $fh "   $_->{'com'}\n\n";
        print $fh "   Default value: \"$_->{'val'}\"\n\n";
    }
    close($fh);
}
my @out = parse_vii( read_vii_database() );
append_man( \@out );
