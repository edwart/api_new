#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw/ $Bin /;
use File::Basename;
use lib (
         $Bin .'/lib',
);


use TkTail;

my @files = ();
foreach my $file (@ARGV) {
	if ($file =~ m/^\w+\.\w+\..*\.log$/) {
        my @bits = split('\.', $file);
        pop(@bits);
        my $label = pop(@bits);
        $label = pop(@bits) if $label =~ m{^(mxres|\d+)$};
		push(@files, [$file, $label]);
	}
	else {
		push(@files, $file);
	}
}
TkTail(@files);
