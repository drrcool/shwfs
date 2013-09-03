#!/usr/bin/perl

$sys = $ARGV[0];
$star = $ARGV[1];

my @x_sys;
my @y_sys;
my @x_star;
my @y_star;

$nsys = 0;
open(SYS, "$sys");
while (<SYS>) {
  chomp;
  if (/X/) {
    ($dum1, $dum2, $sys_xmag, $sys_ymag, $sys_xcen, $sys_ycen) = split(' ');
  }
  next if /#/;
  next if /^\s*$/;

  @data = split(' ');
  push @x_sys, $data[0];
  push @y_sys, $data[1];
  $nsys++;
}
close(SYS);
$sys_mag = ($sys_xmag + $sys_ymag)/2;

$nstar = 0;
open(STAR, "$star");
while (<STAR>) {
  chomp;
  if (/X/) {
    ($dum1, $dum2, $star_xmag, $star_ymag, $star_xcen, $star_ycen) = split(' ');
  }
  next if /#/;
  next if /^\s*$/;

  @data = split(' ');
  push @x_star, $data[0];
  push @y_star, $data[1];
  $nstar++;
}
close(STAR);
$star_mag = ($star_xmag + $star_ymag)/2;

# apply offset only to system file
for ($i=0; $i<$nsys; $i++) {
  $x_sys[$i] -= $sys_xcen;
  $y_sys[$i] -= $sys_ycen;
  $used[$i] = 0;
}

# differential mag
$mag = $sys_mag/$star_mag;

# apply offset and diff mag to star file
for ($i=0; $i<$nstar; $i++) {
  $x_star[$i] = ($x_star[$i] - $star_xcen)*$mag;
  $y_star[$i] = ($y_star[$i] - $star_xcen)*$mag;
  $star_flag[$i] = 0;
}

# now associate the spots
my @link_sys;
my @link_star;
my @tlink;

$nlink = 0;
$xave = 0;
$yave = 0;
$xabs = 0;
$yabs = 0;

for ($i=0; $i<$nstar; $i++) {
  $rmin = 500;

  for ($j=0; $j<$nsys; $j++) {
    if ($used[$j] == 0) {
      $dist = sqrt(($x_star[$i]-$x_sys[$j])**2 + ($y_star[$i]-$y_sys[$j])**2);
      if ($dist < $rmin) {
	$rmin = $dist;
	$lnk = $j;
      }
    }
  }

  # init to no link
  $tlink[$i] = -1;

  # check to see if link is close enough to be valid
  if ($rmin < 10) {
    $tlink[$i] = $lnk;
    $used[$lnk] = 1;
    $xave += $x_star[$i] - $x_sys[$lnk];
    $yave += $y_star[$i] - $y_sys[$lnk];
    $xabs += abs($x_star[$i] - $x_sys[$lnk]);
    $yabs += abs($y_star[$i] - $y_sys[$lnk]);
    $nlink++;
  }

#  print "$i $tlink[$i]\n";

}

$xave /= $nlink;
$yave /= $nlink;
$xabs /= $nlink;
$yabs /= $nlink;

if ($xave < 0) {
  $xabs *= -1;
}

if ($yave < 0) {
  $yabs *= -1;
}

print "$xabs $yabs\n";

