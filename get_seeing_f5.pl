#!/usr/bin/perl

  my $hwfm = $ARGV[0];

  # 6000 A is a pretty close approx for both WFS's
  my $lambda = 0.6e-6;

  # 14 apertures/pupil is also pretty close for both cases
  # certainly for f/5 while f/9 is a little funky with the hex geom
  my $d = 6.5/14;
  my $r = $d;

  if ($hwfm > 1.25) {
    my $fwhm = sqrt(2.0)*sqrt((2*$hwfm)**2 - 2.5**2)*20;

    my $s = ($fwhm**2)/(8*log(2));

    my $r0 = ( 2.0*$lambda*($d**(-1/3))*(0.179-0.0968)/($s) )**(0.6);

    $seeing = 0.98*$lambda/$r0;
    print "Seeing = $seeing\n";
  }


