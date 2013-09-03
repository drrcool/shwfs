#!/usr/bin/perl

use PDL;
use PDL::Graphics::PGPLOT::Window;

$foc = $ARGV[0];

if (!$foc) {
  $foc = "F9";
}

($sys_x, $sys_y) = rcols 'sys_dim.cntr';
($stel_x, $stel_y) = rcols 'stel_dim.cntr';

$sub_x = $stel_x - $sys_x;
$sub_y = $stel_y - $sys_y;

@stats_x = stats($sub_x);
@stats_y = stats($sub_y);

$stel_x -= $stats_x[0];
$stel_y -= $stats_y[0];

$win = PDL::Graphics::PGPLOT::Window->new(Device => '/ps',
                                          BORDER => { TYPE => 'rel',
                                                      VALUE => 0.05 },
					  NXpanel => 2,
					  NYpanel => 1,
					  );

$win->points($sys_x, $sys_y, {SYMBOL => DOT,
			      XRange => [-220, 220],
			      YRange => [-220, 220],
			      Axis => [-2, -2],
			      Justify => 1});
$win->hold;

for ($i=0; $i<$sys_x->dim(0); $i++) {
  $x1 = $sys_x->at($i);
  $y1 = $sys_y->at($i);
  $x2 = $stel_x->at($i);
  $y2 = $stel_y->at($i);

  $size = 0.3*sqrt(($x2-$x1)**2 + ($y2-$y1)**2);

  $win->arrow($x1, $y1, $x2, $y2, {Arrow => {FS => 1, 
					     Angle => 60, 
					     Vent => 0.3, 
					     Size => $size}});
}

$win->release;

$win->panel(1);

if ($foc == "F5") {
  $diff_x = 0.135*($stel_x - $sys_x);
  $diff_y = 0.135*($stel_y - $sys_y);
} elsif ($foc == "F9") {
  $diff_x = 0.12*($stel_x - $sys_x);
  $diff_y = 0.12*($stel_y - $sys_y);
} else {
  $diff_x = 0.208*($stel_x - $sys_x);
  $diff_y = 0.208*($stel_y - $sys_y);
}

($minx, $maxx) = minmax(abs($diff_x));
($miny, $maxy) = minmax(abs($diff_y));

$win->points($diff_x, $diff_y, {XRange => [-1, 1],
				YRange => [-1, 1],
				Justify => 1,
				XTitle => "X (arcsec)",
				YTitle => "Y (arcsec)",
			       });

$win->close;

#system("convert -density 60x60 -rotate 90 -transparent white pgplot.ps spot_motion.xpm");
system("convert -density 60x60 -rotate 90 pgplot.ps spot_motion.xpm");
