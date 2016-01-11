#!/usr/bin/perl -w

use PDL;

$file = $ARGV[0];

die "Reference image. Ignoring....\n\n" if $file =~ /Ref/;
die "Reference image. Ignoring....\n\n" if $file =~ /ref/;
die "Pixelink image. Ignoring....\n\n" if $file =~ /pix/;
die "Apogee image. Ignoring....\n\n" if $file =~ /sci/;
die "Combined exposure. Ignoring....\n\n" if $file =~ /_ave\./;
die "Background image. Ignoring....\n\n" if $file =~ /back\.fits/;
die "Tmp image. Ignoring....\n\n" if $file =~ /tmp\.fits/;

$fits = $file;
$file =~ s/\.fits//;
$sf = $file . ".sf";
$as = $file . ".allstar";
$seeing = $file . ".seeing";
$cntr = $file . ".center";
$dao = $file . ".dao";
$psf_f = $file . ".psf";
$out = $file . ".output";

open(OUT, "> $out");

$data = rfits $fits;
$airmass = $data->fhdr->{AIRMASS};
if (!$airmass || $airmass < 1.0) {
  $airmass = -1.0;
}

$exptime = $data->fhdr->{EXPTIME};
if (!$exptime) {
  $exptime = 0.0;
}

$az = $data->fhdr->{AZ};
if (!$az) {
  $az = 180.0;
}

$el = $data->fhdr->{EL};
if (!$el) {
  $el = 90.0;
}

$rot = $data->fhdr->{ROT};
if (!$rot) {
  $rot = 0.0;
}

$dirdate = `pwd | awk -F \"/\" \'{print \$4}\'`;
chomp($dirdate);
$year = substr $dirdate, 0, 4;
$month = substr $dirdate, 4, 2;
$day = substr $dirdate, 6, 2;
$date = "$year-$month-$day";

$time = $data->fhdr->{'UT'};
if (!$time) {
  $time = $data->fhdr->{'TIME-OBS'};
  if (!$time) {
    $time = "00:00:00.0";
  }
}

system("xpaset -p WFS cd `pwd`");
system("xpaset -p WFS file $fits");

if (-e "F9") {
  print "We're in F9 mode.\n";
  $mode = "F9";
  $reffwhm = 2.92;
  $scale = 0.12;
  $rotoff = -225.0
} elsif (-e "F5") {
  print "We're in F5 mode.\n";
  $mode = "F5";
  $reffwhm = 2.16;
  $scale = 0.135;
  $rotoff = 135.0;
} elsif (-e "MMIRS") {
  $mode = "MMIRS";
  $reffwhm = 1.82;
  ##  $scale = 0.208;  <-- original value, but this is MMIRS not the guider
  $scale = 0.16
  $rotoff = 0.0;
} else {
  die "Specify mode.\n";
}

print "Working on $fits...\n";
if (-e $sf || -e $as) {
  ### use starfind results if available; works in worse seeing ###
  print "Starfind file exists.\n";
  if (-e $cntr) {
    print "Cntr file exists, using it....\n";
    $psf = psfmeasure($fits, $psf_f, $cntr);
    print "FWHM = $psf\n";
    if ($psf && $psf > 0) {
      $see_as = dimm_seeing($psf, $reffwhm, $scale);
      print "$date $time $exptime $az $el $rot $airmass $psf $see_as\n";  
      print OUT "$date $time $exptime $az $el $rot $airmass $psf $see_as $mode $out\n";  
      ds9spots($cntr, $psf, $see_as);
    } else {
      print "psfmeasure failed.  moving on.....\n";
      close(OUT);
      system("rm -f $out");
      exit;
    }
  } else {
    print "need cntr file.  moving on...\n\n";
    close(OUT);
    system("rm -f $out");
    exit;
  }
} elsif (-e $dao) {
  ### parse output from previous daofind run to make new output file ###
  print "daofind.py output exists, recent analysis.\n";
  my @olddat;
  if (-e $seeing) {
    $old = `cat $seeing`;
    chomp($old);
    @olddat = split(' ', $old);
    $see_as = sprintf("%.3f", pop @olddat);
    $psf = sprintf("%.4f", pop @olddat);
    print "$date $time $exptime $az $el $rot $airmass $psf $see_as\n";  
    print OUT "$date $time $exptime $az $el $rot $airmass $psf $see_as $mode $out\n";  
    ds9spots($dao, $psf, $see_as);
  }
} else {
  ### image not done so run it through daofind ###
  print "Image not analyzed, start over from scratch.\n";
  system("/mmt/shwfs/daofind.py $fits $mode 30");
  if (-e $seeing) {
    $old = `cat $seeing`;
    chomp($old);
    @olddat = split(' ', $old);
    $see_as = sprintf("%.3f", pop @olddat);
    $psf = sprintf("%.4f", pop @olddat);
    print "$date $time $exptime $az $el $rot $airmass $psf $see_as\n";  
    print OUT "$date $time $exptime $az $el $rot $airmass $psf $see_as $mode $out\n";  
  } else {
    print "daofind failed.  moving on...\n\n";
    close(OUT);
    system("rm -f $out");
    exit;
  }

}

$blah = `cat $cntr`;
chomp($blah);

#($xcen, $ycen) = split(' ', $blah);

#draw_dirs($rot, $rotoff, $xcen, $ycen, 35.0);

print "\n";

close(OUT);

sub draw_dirs {
  my ($r, $off, $x, $y, $l) = @_;
  my $pi = 4.0*atan(1.0);
  my $el = $r + $off + 90;
  my $az = $el + 270;
  my $ang = $pi*($r + $off)/180.0;
  my $el_y = $l/( (sin($ang)**2/cos($ang)) + cos($ang) );
  my $el_x = -1*$el_y*sin($ang)/cos($ang);
  my $az_y = $l/( (cos($ang)**2/sin($ang)) + sin($ang) );
  my $az_x = $az_y*cos($ang)/sin($ang);

  my $lel_y = ($l-10)/( (sin($ang)**2/cos($ang)) + cos($ang) );
  my $lel_x = -1*$lel_y*sin($ang)/cos($ang);
  my $laz_y = ($l-10)/( (cos($ang)**2/sin($ang)) + sin($ang) );
  my $laz_x = $laz_y*cos($ang)/sin($ang);

  $el_x += $x;
  $el_y += $y;
  $az_y += $y;
  $az_x += $x;

  $lel_x += $x;
  $lel_y += $y;
  $laz_y += $y;
  $laz_x += $x;

  system("echo \'image;text $el_x $el_y # text={+El}\' | xpaset WFS regions");
  system("echo \'image;text $az_x $az_y # text={+Az}\' | xpaset WFS regions");
  system("echo \'image;vector $x $y 25 $az' | xpaset WFS regions");
  system("echo \'image;vector $x $y 25 $el' | xpaset WFS regions");
}

sub psfmeasure {
  my ($file, $log, $coords) = @_;
  system("rm -f $log");

  my $fwhm = `/mmt/shwfs/psfmeasure psfmeasure $file coords=\"markall\" wcs=\"logical\" display=no frame=1 level=0.5 size=\"FWHM\" radius=10.0 sbuffer=1.0 swidth=3.0 iterations=1 logfile=\"$log\" imagecur=\"$coords\" graphcur=\"/mmt/shwfs/end\" | grep Average | awk '{print \$9}'`;

  chomp($fwhm);

  return $fwhm;

}

sub dimm_seeing {
  my ($fwhm, $ref_fwhm, $scale) = @_;
  # this is the eff wavelength of both systems 
  my $lamb = 0.65e-6 ;

  # 14 apertures/pupil is also pretty close for both cases 
  # certainly for f/5 while f/9 is a little funky with the hex geom 
  my $d = 6.5/14.0;
 
  # reference files give me a mean fwhm of about 2.1-2.15 pix 
  if ($fwhm > $ref_fwhm) {
    # 
    # deconvolve reference fwhm and convert to radians. 
    # 
    my $f = sqrt(2.0)*sqrt($fwhm**2 - $ref_fwhm**2)*$scale/206265.0;
    my $s = ($f**2)/(8*log(2));
 
    my $r0 = ( 0.358*($lamb**2)*($d**(-1.0/3.0))/$s )**0.6;
    my $seeing = 206265*0.98*$lamb/$r0;
    $seeing = sprintf("%.3f", $seeing);
    return $seeing;
  } else {
    return 0.0;
  }

}

sub ds9spots {
  my ($file, $pix, $fwhm) = @_;

  open(XPA, "> ds9.reg");
  open(DAT, $file);
  print XPA "# Region file format: DS9 version 3.0\n";
  print XPA "# Filename: $file\n";
  print XPA "global color=red font=\"helvetica 10 normal\" select=1 edit=1 move=1 delete=1 include=1 fixed=0 source\n";

  my @dat;
  while(<DAT>) {
    chomp;
    next if /#/;
    @dat = split(' ');
    print XPA "image;circle($dat[0],$dat[1],1) # color = red\n";
  }
  close(DAT);
  close(XPA);
  system("cat ds9.reg | xpaset WFS regions");
  system("echo \"image;text 95 500 # text={Spot FWHM = $pix pixels}\" | xpaset WFS regions");
  system("echo \'image;text 460 500 # text={Seeing = $fwhm\"}\' | xpaset WFS regions");
}
