#!/usr/bin/perl

# script to query network servers and place info in image headers

use IO::Socket::INET;
use PDL;

if (-e "stella.fits") {
  system("rm -f stella.fits");
}

system("/mmt/shwfs/stella_acquire");

$img = rfits 'stella.fits';

# set up the WCS headers
$img->fhdr->{'CTYPE1'} = "LINEAR";
$img->fhdr->{'CTYPE1_COMMENT'} = "Azimuth";
$img->fhdr->{'CTYPE2'} = "LINEAR";
$img->fhdr->{'CTYPE2_COMMENT'} = "Elevation";
$img->fhdr->{'CDELT1'} = 1;
$img->fhdr->{'CDELT1_COMMENT'} = "Azimuth Pixel Scale";
$img->fhdr->{'CDELT2'} = -1;
$img->fhdr->{'CDELT2_COMMENT'} = "Elevation Pixel Scale";
$img->fhdr->{'CRVAL1'} = 255;
$img->fhdr->{'CRVAL1_COMMENT'} = "Reference Azimuth";
$img->fhdr->{'CRVAL2'} = 255;
$img->fhdr->{'CRVAL2_COMMENT'} = "Reference Elevation";
$img->fhdr->{'CRPIX1'} = 255;
$img->fhdr->{'CRPIX1_COMMENT'} = "Reference Azimuth Pixel";
$img->fhdr->{'CRPIX2'} = 255;
$img->fhdr->{'CRPIX2_COMMENT'} = "Reference Elevation Pixel";

$rot = `echo "get rot" | nc hacksaw 7694`;
$img->fhdr->{'CROTA2'} = (124.1 + $rot);
$img->fhdr->{'CROTA2_COMMENT'} = "Sky Angle";

# set up the FITS header comments
$img->fhdr->{'BITPIX_COMMENT'} = "number of bits per data pixel";
$img->fhdr->{'NAXIS_COMMENT'} = "number of data axes";
$img->fhdr->{'NAXIS1_COMMENT'} = "length of data axis 1";
$img->fhdr->{'NAXIS2_COMMENT'} = "length of data axis 2";

# write the results back to input
$img->wfits("$ARGV[0]");
system("rm -f stella.fits");

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

