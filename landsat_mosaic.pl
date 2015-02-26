#!/usr/bin/perl
#############################################################################
#
# This must be run from with Grass and must be run from the location
# into which you wish to bring all Landsat files.  Landsat files should
# be reflectances in the form R8_???????.* (ie they should be from Landsat 8)
# and they should all reside in locations within the current GISDBASE. There
# should be nothing else in the GISDBASE directory, otherwise it will be
# mistaken for a relevant location.
#
# The new (current) location can represent your desired region of interest
#
# Damien 2014-04-01 (April's fool)
# Modified 2014-08-07
#
# ###########################################################################

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

my @locations = @{get_locations()} or die "Couldn't find any locations \n";
my %newmaps; # to store $newmaps{band} = [name1, name2, ...namen]
my $domosaic = 0;
my $input = '';
while ($input !~ /[ynYN]/) {
        print "Do you want images mosaicked? (useless if they are a time series of the same region)(y/n)\n";
        $input = <STDIN>;
        $domosaic = ($input =~ /[yY]/);
}

foreach my $location (@locations) {
        my @maps = @{get_maps($location)};
        foreach my $map (@maps) {
                my $newname = "$location"."_$map";
                my $band = get_band($map);
                reproject_here($location, $map, $newname, $band);
                $newmaps{$band} = [] unless defined($newmaps{$band});
                push @{$newmaps{$band}}, $newname;
        }
}

# die("stopping here for now without mosaicking for inspection purposes\n");
mosaic() if $domosaic ;

###############################################################################
sub mosaic {
	foreach my $band (sort keys %newmaps) {
		my $res = ($band == 8 ? 15 : 30);
		system "g.region res=$res ";
	        my @maps = @{$newmaps{$band}};
	        my $string = 'null()';
	        foreach my $map (@maps) {
	                $string =~ s/null\(\)/if(isnull($map),null(),$map)/;
	        }
	        print "\n\n\nMosaicking band $band...\n";
	        system "r.mapcalc 'mosaic.$band = $string' ";
	        system "bw mosaic.$band ";
	}
}

sub get_band {
        my $map = shift;
        if ($map =~ /[^.]+\.([a-zA-Z0-9]+)/) {
                return $1;
        }
        return 0;
}

sub reproject_here {
        my ($location, $map, $newname, $band) = @_;
	my $res = ($band == 8 ? 15 : 30);
	system "g.region res=$res ";
        system "r.proj loc=$location inp=$map out=$newname ";
}

sub get_maps { 
        my $location = shift;
        my @maps;
        my $GISDBASE = `g.gisenv get=GISDBASE`;
        chomp $GISDBASE;
        opendir my ($dh), "$GISDBASE/$location/PERMANENT/cell_misc" or die "Couldn't open dir '$GISDBASE/$location/PERMANENT/cell_misc': $!";
        my @files = readdir $dh;
        closedir $dh;
        foreach my $map (@files) {
                push(@maps, $map) if ($map =~ /R[578]_\d{7}\.\d/);
        }
        return \@maps;
}

sub get_locations {
        my @locations;
        my $GISDBASE = `g.gisenv get=GISDBASE`;
        chomp $GISDBASE;
	my $CURRENT_LOCATION = `g.gisenv get=LOCATION_NAME `;
	chomp $CURRENT_LOCATION;
        opendir my($dh), $GISDBASE or die "Couldn't open dir '$GISDBASE': $!";
        my @files = readdir $dh;
        closedir $dh;
        foreach my $location (@files) {
                push(@locations, $location) unless (($location eq $CURRENT_LOCATION) || ($location =~ /^\./));
        }
        return \@locations;
}
