#!/usr/bin/perl

$sys = $ARGV[0];

$out = "f5sysfile.cntr";

open(OUT, "> $out");

open(SYS, "$sys");
while (<SYS>) {
  chomp;
  if (/X/) {
    ($dum1, $dum2, $sys_xmag, $sys_ymag, $sys_xcen, $sys_ycen) = split(' ');
  }
  next if /#/;
  next if /^\s*$/;

  ($x, $y) = split(' ');

  $dist = sqrt(($x-$sys_xcen)**2 + ($y-$sys_ycen)**2);

  if ($dist > 40 && $dist < 180) {
#    system("xpaset -p ds9 regions circle $x $y 1\n");
    print OUT "$x $y\n";
  }

}
close(SYS);

close(OUT);
