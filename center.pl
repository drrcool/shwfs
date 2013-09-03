#!/usr/bin/perl

use PDL;

$fitsfile = $ARGV[0];
$mean = $ARGV[1];

$img = rfits($fitsfile);

$img = $img->setbadif($img<$mean);

$ysum = sumover($img);
$xsum = sumover($img->xchg(0,1));

$ycum = cumusumover($ysum);
($ymin, $ymax) = minmax($ycum);

$xcum = cumusumover($xsum);
($xmin, $xmax) = minmax($xcum);

$bot = 0.25;
$top = 1-$bot;

for ($i=0; $i<$xcum->dim(0); $i++) {
  if ($xcum->at($i) > $bot*$xmax) {
    $xlower = interp($bot*$xmax,$i-1,$i,$xcum->at($i-1),$xcum->at($i));
    last;
  }
}

for ($i=0; $i<$xcum->dim(0); $i++) {
  if ($xcum->at($i) > $top*$xmax) {
    $xupper = interp($top*$xmax,$i-1,$i,$xcum->at($i-1),$xcum->at($i));
    last;
  }
}

for ($i=0; $i<$ycum->dim(0); $i++) {
  if ($ycum->at($i) > $bot*$ymax) {
    $ylower = interp($bot*$ymax,$i-1,$i,$ycum->at($i-1),$ycum->at($i));
    last;
  }
}

for ($i=0; $i<$ycum->dim(0); $i++) {
  if ($ycum->at($i) > $top*$ymax) {
    $yupper = interp($top*$ymax,$i-1,$i,$ycum->at($i-1),$ycum->at($i));
    last;
  }
}

$xcen = ($xupper + $xlower)/2;
$ycen = ($yupper + $ylower)/2;

print "$xcen $ycen\n";


sub interp {
  my ($y, $xl, $xu, $yl, $yu) = @_;
  my $x;

  $x = $xl + ($y-$yl)*($xu-$xl)/($yu-$yl);
  return $x;
}
