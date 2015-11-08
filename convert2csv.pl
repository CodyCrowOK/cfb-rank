#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;

my $input = shift;

open my $fh, "<", $input or die "$input: $!";

my @lines = [];

while (<$fh>) {
	if (!@lines) {
		$lines[0] = $_;
	} else {
		my $i = 0;
		for my $element (@lines) {
			#SPLICE
			$i++;
		}
	}
}
