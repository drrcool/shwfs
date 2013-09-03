#!/usr/bin/perl

# script to query network servers and place info in image headers

use IO::Socket::INET;
use PDL;

# read the image in from the command line
sleep(1);

if ($ARGV[0]) {
  $img = rfits("$ARGV[0]")->hcpy(1);
} else {
  die "Please specify an image.\n";
}

#$img->fhdr->{'BZERO'} = 32768;

if ($ARGV[1]) {
  $exptime = $ARGV[1];
} else {
  die "Please specify an exposure time.\n";
}

# interesting stuff contained in telserver
my @telserver_stuff = qw/ra dec az el ut lst ha airmass rot pa cat_id 
  telname epoch dateobs mjd/;

# hexapod goodies
my @hexapod_stuff = qw/curr_temp tiltx tilty transx transy focus/;

# various thermal goodies from the dataserver
# vaisala first...
my @dataserver_stuff = qw/vaisala_ambient_temperature 
  vaisala_relative_humidity vaisala_dewpoint_temperature 
  vaisala_wetbulb_temperature vaisala_absolute_humidity vaisala_mixing_ratio/;

# now some cell TC's
for ($i=0; $i<=111; $i++) {
  $temp = sprintf("cell_e_tc%d_C", $i);
  push @dataserver_stuff, $temp;
}

# FITS header keywords are 8 chars long so abbreviate
my @dataserver_header = qw/AMB_TEMP REL_HUM DEWPOINT WETBULB ABS_HUM 
  MIX_RAT/;

for ($i=0; $i<=111; $i++) {
  $temp = sprintf("TC_%03d", $i);
  push @dataserver_header, $temp;
}

# whack the telserver stuff in....
$ts_socket = IO::Socket::INET->new(PeerAddr => "hacksaw",
				   PeerPort => 5403,
				   Proto => "tcp",
				   Type => SOCK_STREAM)
  or die "Couldn't connect to telserver: $!\n";

foreach $item (@telserver_stuff) {
  $data = telserver_get($item);

  $item =~ tr/a-z/A-Z/;

  $img->fhdr->{$item} = $data;
}

close($ts_socket);

# now hexapod....
$hex_socket = IO::Socket::INET->new(PeerAddr => "hexapod",
				    PeerPort => 5350,
				    Proto => "tcp",
				    Type => SOCK_STREAM)
  or die "Couldn't connect to hexapod: $!\n";


foreach $item (@hexapod_stuff) {
  $data = f5_get($item);

  $item =~ tr/a-z/A-Z/;
  $item =~ s/_//;
  $item =~ s/CURR/OSS/;

  $img->fhdr->{$item} = $data;
}

close($hex_socket);

# exposure time
$img->fhdr->{'EXPTIME'} = $exptime;

# and now the thermal......
$n = 0;
#foreach $item (@dataserver_stuff) {
#  $data = dataserver_get($item);
#  $item = $dataserver_header[$n];
#  $n++;
#  $img->fhdr->{$item} = $data;
#}

# set up the WCS headers
$img->fhdr->{'CTYPE1'} = "LINEAR";
$img->fhdr->{'CTYPE1_COMMENT'} = "Azimuth";
$img->fhdr->{'CTYPE2'} = "LINEAR";
$img->fhdr->{'CTYPE2_COMMENT'} = "Elevation";
$img->fhdr->{'CDELT1'} = 1;
$img->fhdr->{'CDELT1_COMMENT'} = "Azimuth Pixel Scale";
$img->fhdr->{'CDELT2'} = 1;
$img->fhdr->{'CDELT2_COMMENT'} = "Elevation Pixel Scale";
$img->fhdr->{'CRVAL1'} = 255;
$img->fhdr->{'CRVAL1_COMMENT'} = "Reference Azimuth";
$img->fhdr->{'CRVAL2'} = 255;
$img->fhdr->{'CRVAL2_COMMENT'} = "Reference Elevation";
$img->fhdr->{'CRPIX1'} = 255;
$img->fhdr->{'CRPIX1_COMMENT'} = "Reference Azimuth Pixel";
$img->fhdr->{'CRPIX2'} = 255;
$img->fhdr->{'CRPIX2_COMMENT'} = "Reference Elevation Pixel";
$img->fhdr->{'CROTA2'} = (234 - 15 + $img->fhdr->{'ROT'});
$img->fhdr->{'CROTA2_COMMENT'} = "Sky Angle";

# add SECZ header
$img->fhdr->{'SECZ'} = $img->fhdr->{'AIRMASS'};

# set up the FITS header comments
$img->fhdr->{'BITPIX_COMMENT'} = "number of bits per data pixel";
$img->fhdr->{'NAXIS_COMMENT'} = "number of data axes";
$img->fhdr->{'NAXIS1_COMMENT'} = "length of data axis 1";
$img->fhdr->{'NAXIS2_COMMENT'} = "length of data axis 2";
$img->fhdr->{'RA_COMMENT'} = "Object RA";
$img->fhdr->{'DEC_COMMENT'} = "Object Dec";
$img->fhdr->{'AZ_COMMENT'} = "Object Az at time of observation";
$img->fhdr->{'EL_COMMENT'} = "Object El at time of observation";
$img->fhdr->{'UT_COMMENT'} = "UT of observation";
$img->fhdr->{'LST_COMMENT'} = "Sidereal Time of observation";
$img->fhdr->{'HA_COMMENT'} = "Hour Angle of observation";
$img->fhdr->{'AIRMASS_COMMENT'} = "Secant of ZD of observation";
$img->fhdr->{'SECZ_COMMENT'} = "Secant of ZD of observation";
$img->fhdr->{'ROT_COMMENT'} = "Instrument Rotator Angle";
$img->fhdr->{'PA_COMMENT'} = "Parallactic Angle";
$img->fhdr->{'CAT_ID_COMMENT'} = "Catalog Source Name";
$img->fhdr->{'TELNAME_COMMENT'} = "Name of Observatory";
$img->fhdr->{'EPOCH_COMMENT'} = "Coordinate Epoch";
$img->fhdr->{'DATEOBS_COMMENT'} = "Date of observation";
$img->fhdr->{'MJD_COMMENT'} = "MJD of observation";
$img->fhdr->{'OSSTEMP_COMMENT'} = "OSS Temperature of observation";
$img->fhdr->{'TILTX_COMMENT'} = "Hexapod X Tilt (arcsec)";
$img->fhdr->{'TILTY_COMMENT'} = "Hexapod Y Tilt (arcsec)";
$img->fhdr->{'TRANSX_COMMENT'} = "Hexapod X Translation (microns)";
$img->fhdr->{'TRANSY_COMMENT'} = "Hexapod Y Translation (microns)";
$img->fhdr->{'FOCUS_COMMENT'} = "Hexapod Focus (microns)";
$img->fhdr->{'EXPTIME_COMMENT'} = "Exposure time (seconds)";

# write the results back to input
$img->wfits("$ARGV[0]", '-32');

###########################################################

# open the dataserver socket and get a parameter from it.
sub dataserver_get {
  my $param = $_[0];

  my $socket = IO::Socket::INET->new(PeerAddr => "hacksaw",
				     PeerPort => 7676,
				     Proto => "tcp",
				     Type => SOCK_STREAM)
    or die "Couldn't connect to dataserver: $!\n";

  # pretty simple command structure....
  print $socket "get $param\n";

  my $answer = <$socket>;
  chomp($answer);

  close($socket);

  return $answer;
}

# open the telserver socket and get a parameter from it.  this is a total
# hack of the msg_get command, but it seems to do the trick. 
sub telserver_get {
  my $param = $_[0];

  # just like i do from a telnet prompt....
  print $ts_socket "1 get $param\n";

  # the result will be of a form "1 ack <data>" so split it up and 
  # $answer[2] will be the result to return.
  my @answer = split(' ', <$ts_socket>);

  return $answer[2];
}

# as above, but talk to the f/5 hexapod crate instead.
sub f5_get {
  my $param = $_[0];

  print $hex_socket "1 get $param\n";

  my @answer = split(' ', <$hex_socket>);

  return $answer[2];
}

