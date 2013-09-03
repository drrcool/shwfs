#!/usr/bin/perl

use PDL;
use PDL::Graphics::PGPLOT;
use PDL::Graphics::PGPLOT::Window;
use PDL::Fit::Linfit;

$file = $ARGV[0];
$hex = $ARGV[1];

my %temp_coeff;
$temp_coeff{'F5'} = 35.3;
$temp_coeff{'F9'} = 46.7;
$temp_coeff{'F15'} = 49;

die "Supply a data file.\n" unless $file;

$pi = 4.0*atan2(1,1);

($el, $tiltx, $tilty, $transx, $transy, $focus, $toss) = rcols $file;

$focus += $temp_coeff{$hex}*$toss;

$ndat = $el->dim(0);

$a = ones $ndat;
$fitfunc = cat $a, sin($el*$pi/180), cos($el*$pi/180);

($focus_fit, $focus_coeffs) = linfit1d($focus, $fitfunc);
$focus_resid = $focus - $focus_fit;
($mean,$focus_rms,$median,$min,$max,$adev,$rms) = stats($focus_resid);
($tiltx_fit, $tiltx_coeffs) = linfit1d($tiltx, $fitfunc);
$tiltx_resid = $tiltx - $tiltx_fit;
($mean,$tiltx_rms,$median,$min,$max,$adev,$rms) = stats($tiltx_resid);
($tilty_fit, $tilty_coeffs) = linfit1d($tilty, $fitfunc);
$tilty_resid = $tilty - $tilty_fit;
($mean,$tilty_rms,$median,$min,$max,$adev,$rms) = stats($tilty_resid);
($transx_fit, $transx_coeffs) = linfit1d($transx, $fitfunc);
$transx_resid = $transx - $transx_fit;
($mean,$transx_rms,$median,$min,$max,$adev,$rms) = stats($transx_resid);
($transy_fit, $transy_coeffs) = linfit1d($transy, $fitfunc);
$transy_resid = $transy - $transy_fit;
($mean,$transy_rms,$median,$min,$max,$adev,$rms) = stats($transy_resid);

print "Fit RMS:\n";
printf "\t FOCUS = %.2f um\n", $focus_rms;
printf "\t TRANSY = %.2f um\n", $transy_rms;
printf "\t TILTX = %.2f arcsec\n", $tiltx_rms;
printf "\t TRANSX = %.2f um\n", $transx_rms;
printf "\t TILTY = %.2f arcsec\n", $tilty_rms;

$win = PDL::Graphics::PGPLOT::Window->new(Device => '?',
                                          BORDER => { TYPE => 'rel',
                                                      VALUE => 0.05 },
                                          NYPanel => 3,
                                          NXPanel => 2,
                                          LINEWIDTH => 1);
$win->points($el, $transy, { XTitle => 'Elevation (deg)',
			     YTitle => 'Y (um)',
			     Title => "Translation along Y-axis"
			  });

$win->hold;
$win->line($el, $transy_fit);
$old = elfit(927.9, -471.6, 1290.8, $el);
$win->line($el, $old, {Color => 'Red'});
$win->release;

$win->panel(1);

$win->points($el, $tiltx, { XTitle => 'Elevation (deg)',
			    YTitle => '\\gH\\dx\\u (arcsec)',
			    Title => "Tilt about X-axis"
			  });

$win->hold;
$win->line($el, $tiltx_fit);
$old = elfit(255.2, -107.1, 88.0, $el);
$win->line($el, $old, {Color => 'Red'});
$win->release;

$win->panel(2);

$win->points($el, $transx, { XTitle => 'Elevation (deg)',
			     YTitle => 'X (um)',
			     Title => "Translation along X-axis"
			  });

$win->hold;
$win->line($el, $transx_fit);
$old = elfit(52.3, -68.8, -450.4, $el);
$win->line($el, $old, {Color => 'Red'});
$win->release;

$win->panel(3);

$win->points($el, $tilty, { XTitle => 'Elevation (deg)',
			    YTitle => '\\gH\\dy\\u (arcsec)',
			    Title => "Tilt about Y-axis"
			  });

$win->hold;
$win->line($el, $tilty_fit);
$old = elfit(81.9, 2.8, 39.8, $el);
$win->line($el, $old, {Color => 'Red'});
$win->release;

$win->panel(4);

$win->points($el, $focus, { XTitle => 'Elevation (deg)',
			    YTitle => 'Z (um)',
			    Title => "Focus"
			  });

$win->hold;
$win->line($el, $focus_fit);
$old = elfit(13608.5, 1132.5, 121.1, $el);
#$old =- $temp_coeff{$hex}*$toss;
$win->line($el, $old, {Color => 'Red'});
$win->release;

$win->panel(5);

$win->env(0, 1, 0, 1, {JUSTIFY => 1, AXIS => -2});

$a = sprintf("%7.1f", $focus_coeffs->at(0));
$b = sprintf("%6.1f", $focus_coeffs->at(1));
$c = sprintf("%6.1f", $focus_coeffs->at(2));
$win->text("Z = $a + $b*sin(el) + $c*cos(el)", -0.35, 1.0, {CHARSIZE => 1.8});
print "FOCUS: $a + $b*sin(el) + $c*cos(el)\n";

$a = sprintf("%7.1f", $transy_coeffs->at(0));
$b = sprintf("%6.1f", $transy_coeffs->at(1));
$c = sprintf("%6.1f", $transy_coeffs->at(2));
$win->text("Y = $a + $b*sin(el) + $c*cos(el)", -0.35, 0.8, {CHARSIZE => 1.8});
print "TRANSY: $a + $b*sin(el) + $c*cos(el)\n";

$a = sprintf("%7.1f", $tiltx_coeffs->at(0));
$b = sprintf("%6.1f", $tiltx_coeffs->at(1));
$c = sprintf("%6.1f", $tiltx_coeffs->at(2));
$win->text("\\gH\\dx\\u = $a + $b*sin(el) + $c*cos(el)", -0.38, 0.7, {CHARSIZE => 1.8});
print "TILTX: $a + $b*sin(el) + $c*cos(el)\n";

$a = sprintf("%7.1f", $transx_coeffs->at(0));
$b = sprintf("%6.1f", $transx_coeffs->at(1));
$c = sprintf("%6.1f", $transx_coeffs->at(2));
$win->text("X = $a + $b*sin(el) + $c*cos(el)", -0.35, 0.5, {CHARSIZE => 1.8});
print "TRANSX: $a + $b*sin(el) + $c*cos(el)\n";

$a = sprintf("%7.1f", $tilty_coeffs->at(0));
$b = sprintf("%6.1f", $tilty_coeffs->at(1));
$c = sprintf("%6.1f", $tilty_coeffs->at(2));
$win->text("\\gH\\dy\\u = $a + $b*sin(el) + $c*cos(el)", -0.38, 0.4, {CHARSIZE => 1.8});
print "TILTY: $a + $b*sin(el) + $c*cos(el)\n";


sub elfit {
  my ($a, $b, $c, $el) = @_;

  return $a + $b*sin($el*$pi/180) + $c*cos($el*$pi/180);

}
