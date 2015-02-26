#!/usr/bin/perl
#
#############################################################################
# This script imports Landsat data into GRASS and converts DN values        #
# to reflactance values.  It also creates RGB and a false colour            #
# composite, and computes the NDVI surface.  Optionally, it calculates      #
# the SAVI also.  The default L value is 0.7, which is hard-coded           #
# so you'll have to change that below if necessary.                         #
#                                                                           #
# This must be run from within the GRASS environment.  It doesn't really    #
# matter which location you start from, new locations will be created for   #
# each of the files imported.  You can then use the landsat_mosaic.pl       #
# script to bring them all into one location of your choice.                #
#                                                                           #
# The script must be run in the directory containing the uncompressed       #
# Landsat director(y/ies).  It will process each stack folder by folder     #
#                                                                           #
# Damien 25 March 2014                                                      #
# Modified majorly 7 August 2014                                            #
#############################################################################


use strict;
use warnings;

my $L = 0.7; #!!!!!!!!!!! SAVI L parameter, if required
my @folders = `ls -d L????????????????????`;
chomp @folders;

my $dosavi = 0;
my $input = '';
while ($input !~ /[ynYN]/) {
        print "After calculating reflectance values, NDVI will be calculated.  Would you like to calculate SAVIs? (y/n)\n";
        $input = <STDIN>;
        $dosavi = ($input =~ /[yY]/);
}

foreach my $root (@folders) {
        if ($root =~ /(L.(\d)\d{6}(\d{7}))/ ) {
                my ($prefix, $midfix) = ($1, "$2_$3");
                chdir $root;
                process_ls($root, $prefix, $midfix);
                chdir "..";
                system "r.out.png R$midfix.vis out=R$midfix"."_vis.png ";
        }
}

sub process_ls {
        my ($root, $prefix, $midfix) = @_;
        my @tifs = `ls *.TIF`;
        chomp @tifs;
        my @bands;
        foreach my $tif (@tifs) {
                if ($tif =~ /$root.B(\d+)\.TIF/) {
                        push @bands, $1;
                }
        }
	system "r.in.gdal $tifs[0] out=temp loc=$prefix ";
	system "g.mapset mapset=PERMANENT location=$prefix ";

        foreach my $band (@bands) {
                print "Importing $root"."_B$band.TIF and setting zero to null\n";
                system "r.in.gdal -e $root"."_B$band.TIF out=L$midfix.$band ";
                system "r.null L$midfix.$band set=0";
        }
        print "Converting $root bands to surface reflectance values\n";
        system "i.landsat.toar inp=L$midfix. out=R$midfix. metfile=$root"."_MTL.txt method=dos4";
        if ($root =~ /L.(\d)/) {
                my $type = $1;
                my ($red, $green, $blue, $nir, $swir);
                if ($type == 8) {
                        ($red, $green, $blue, $nir, $swir) = (4,3,2,5,7);
                } else {
                        ($red, $green, $blue, $nir, $swir) = (3,2,1,4,7);
                }
                foreach my $band ($red, $green, $blue, $nir, $swir) {
                        system "bw R$midfix.$band ";
                }
                print "Creating colour composites for $root\n";
                system "r.composite red=R$midfix.$red green=R$midfix.$green blue=R$midfix.$blue out=R$midfix.rgb ";
                system "r.composite red=R$midfix.$swir green=R$midfix.$nir blue=R$midfix.$green out=R$midfix.vis ";
                print "Calculating NDVI for $root\n";
                system "r.mapcalc 'R$midfix.ndvi = (R$midfix.$nir - R$midfix.$red) / (R$midfix.$nir + R$midfix.$red)' ";
                system "r.mapcalc 'R$midfix.savi = (R$midfix.$nir - R$midfix.$red)*(1 + $L) / (R$midfix.$nir + R$midfix.$red + $L)' " if $dosavi;
                system "r.colors R$midfix.ndvi col=ndvi ";
        }
}

