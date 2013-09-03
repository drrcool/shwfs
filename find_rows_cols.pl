#!/usr/bin/perl

use PDL;

($x, $y) = rcols "$ARGV[0]";

($xmean, $xrms, $xmed, $xmin, $xmax) = stats($x);
($ymean, $yrms, $ymed, $ymin, $ymax) = stats($y);

$xhist = hist($x,0,500,1);
$yhist = hist($y,0,500,1);

$nrows = 0;
$ncols = 0;

$found_col = 0;
$found_row = 0;

$xsum = 0;
$sum = 0;

$yysum = 0;
$ysum = 0;

$xgap = 0;
$ygap = 0;

my @rows;
my @row_w;
my @cols;
my @col_w;

for ($i = 0; $i < 500; $i++) {

  # handle columns (x values)
  $colval = $xhist->at($i);

  if ($colval > 1 && $found_col == 0) {
    $found_col = 1;
  }

  if ($colval <= 1 && $found_col == 1 && $xgap < 5) {
    $xgap++;
  }

  if ($colval <= 1 && $found_col == 1 && $xgap == 5) {
    $found_col = 0;
    $xval = $xsum/$sum;
    push @cols, $xval;
    push @col_w, $sum;
    $ncols++;
    $xsum = 0;
    $sum = 0;
    $xgap = 0;
  }

  if ($found_col == 1) {
    $xsum += $i*$colval;
    $sum += $colval;
  }

  # handle rows (y values)
  $rowval = $yhist->at($i);

  if ($rowval > 1 && $found_row == 0) {
    $found_row = 1;
  }

  if ($rowval <= 1 && $found_row == 1 && $ygap < 5) {
    $ygap++;
  }

  if ($rowval <= 1 && $found_row == 1 && $ygap == 5) {
    $found_row = 0;
    $yval = $yysum/$ysum;
    push @rows, $yval;
    push @row_w, $ysum;
    $nrows++;
    $yysum = 0;
    $ysum = 0;
    $ygap = 0;
  }

  if ($found_row == 1) {
    $yysum += $i*$rowval;
    $ysum += $rowval;
  }

}

print "$nrows $ncols ";

$xsum = 0;
for ($i = 1; $i < $ncols; $i++) {
  $xsum += $cols[$i] - $cols[$i-1];
}
$xsum /= $ncols;

$ysum = 0;
for ($i = 1; $i < $nrows; $i++) {
  $ysum += $rows[$i] - $rows[$i-1];
}
$ysum /= $nrows;
#$ysum *= 1.732;

$c = pdl @cols;
$c_w = pdl @col_w;
$r = pdl @rows;
$r_w = pdl @row_w;

@c_stats = stats($c);
@r_stats = stats($r);

$c_ave = $c_stats[0];
$r_ave = $r_stats[0];

printf "%.4f %.4f %.4f %.4f\n", $xsum, $ysum, $c_ave, $r_ave;
