#!/usr/bin/perl
#
use strict;
use warnings;

######################################################################################
# This is intended to take three arguments, the first being the base map, and the second
# being a map which you wish to mosaic to the first.  The third argument is the name you
# want to give the output map.                          It is assumed that the two maps
# overlap.  Regression is carried out using the region in which the two maps overlap,
# and then the resulting coefficients are used to apply a linear transformation to the
# second map by way of a radiometric "correction", to try to "blend" the two maps
# together.
#
# Damien O'Grady 26-Feb-2015
# ####################################################################################
#
my ($base, $map, $output) = @ARGV or die "You must argue a base map and another map to merge\n";

my %coeffs = split /[=\n\r]/, `r.regression.line -g map1=$map map2=$base `;

system "r.mapcalc '$output = if(isnull($map), $base, $coeff{b} * $map + $coeff{a})' ";
