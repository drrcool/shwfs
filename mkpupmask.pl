#!/usr/bin/perl

$file = $ARGV[0];

open(FILE, "$file");

while (<FILE>) {
  next if /^\s*$/;
  next if /^#/;

  ($x, $y) = split(' ');

  $newx = int($x + 0.5);
  $newy = int($y + 0.5);

  print "$newx $newy\n";

}

close(FILE);
