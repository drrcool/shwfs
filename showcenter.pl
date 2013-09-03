#!/usr/bin/perl

# this is going to require a fully qualified path name for ds9 to grok it
$fits_file = $ARGV[0];

if ($fits_file !~ /\//) {
  die "Profide a full pathname to the image file.\n";
}

$cen_file = $fits_file;
$cen_file =~ s/fits/cntr/;
$reg_file = "/tmp/cen.reg";

# make a .reg file and then load it via xpaset
# way, way, WAAAY faster than doing xpaset region by region!!!
open(XPA, "> $reg_file") || die "Can't open $reg_file\n";
print XPA "# Region file format: DS9 version 3.0\n";
print XPA "# Filename: $fits_file\n";
print XPA "global color=green font=\"helvetica 10 normal\" select=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n";

open(CENTROIDS, "cat $cen_file |") || die "Can't open centroids file.\n";

$npoints = 0;

while (<CENTROIDS>) {
  if (/^#/) {
      ($blah1, $blah2, $magx, $magy, $cenx, $ceny) = split(' ');
      print XPA "image;circle($cenx,$ceny,5)\n";
      last;
  }

  next if /^\s*$/;

  chomp;

  $point = $_;

  ($x, $y) = split(' ');

  if ($point) {
    $npoints++;
  }

}

close(CENTROIDS);

if ($npoints == 0) {
  print XPA "image;circle(0,0,1) # color = red\n";
}

close(XPA);

system("/usr/bin/xpaset -p WFS regions load $reg_file");
system("rm -f $reg_file");
