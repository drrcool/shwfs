#!/usr/bin/perl

# script to query network servers and place info in image headers

use IO::Socket::INET;
use Astro::FITS::Header;
use Astro::Time;
use PDL;
#use SOAP::Lite;
use JSON;
use Net::DNS;


($tcs_host, $tcs_port) = srv_lookup('telstat');

#$telstat = SOAP::Lite
#    -> proxy("http://$tcs_host:$tcs_port/")
#    -> uri('urn:Telstat');
#
#%data = %{$telstat->current_data("raw")->result};
#
# replace soap with new protocol
# skip 20150901
#

my $sock = IO::Socket::INET->new ( PeerAddr => $tcs_host, PeerPort => $tcs_port, Timeout => 120.0 );
my $tcs_response = "";
if ($sock) {
    $sock->send("current_data raw\n");
    $sock->recv($tcs_response, 10240);
    $sock->close();
}
%data = %{from_json($tcs_response)};

if ($ARGV[0]) {
    system("cat $ARGV[0] | sed \'s/ENDTIME/FOOTIME/\' > /mmt/shwfs/datadir/tmp.fits");
    $img = rfits("/mmt/shwfs/datadir/tmp.fits")->hcpy(1);
} else {
    die "Please specify an image.\n";
}

if ($ARGV[1]) {
  $exptime = $ARGV[1];
} else {
  die "Please specify an exposure time.\n";
}

if ($ARGV[2]) {
  $sec = $ARGV[2];
} else {
  die "Please specify a secondary mode.\n";
}

# hexapod goodies
my @hexapod_stuff = qw/curr_temp tiltx tilty transx transy focus/;

# now hexapod....
($hex_host, $hex_port) = srv_lookup('hexapod-msg');
$hex_socket = IO::Socket::INET->new(PeerAddr => $hex_host,
				    PeerPort => $hex_port,
				    Proto => "tcp",
				    Type => SOCK_STREAM)
  or die "Couldn't connect to hexapod: $!\n";

foreach $item (@hexapod_stuff) {
  $data = msg_get($item, $hex_socket);

  $item =~ tr/a-z/A-Z/;
  $item =~ s/_//;
  $item =~ s/CURR/OSS/;

  $img->fhdr->{$item} = $data;
}

close($hex_socket);

$img->fhdr->{'OSSTEMP_COMMENT'} = "OSS Temperature of observation";
$img->fhdr->{'TILTX_COMMENT'} = "Hexapod X Tilt (arcsec)";
$img->fhdr->{'TILTY_COMMENT'} = "Hexapod Y Tilt (arcsec)";
$img->fhdr->{'TRANSX_COMMENT'} = "Hexapod X Translation (microns)";
$img->fhdr->{'TRANSY_COMMENT'} = "Hexapod Y Translation (microns)";
$img->fhdr->{'FOCUS_COMMENT'} = "Hexapod Focus (microns)";

$rot = $data{'Rotator Angle'};

if ($sec =~ /F5/) {
# exposure time
  $img->fhdr->{'EXPTIME'} = $exptime;
  $img->fhdr->{'EXPTIME_COMMENT'} = "Exposure time (seconds)";
  $img->fhdr->{'SEC'} = "F5";
  $img->fhdr->{'SEC_COMMENT'} = "Secondary Mirror";
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
  $img->fhdr->{'CRPIX1'} = 254;
  $img->fhdr->{'CRPIX1_COMMENT'} = "Reference Azimuth Pixel";
  $img->fhdr->{'CRPIX2'} = 255;
  $img->fhdr->{'CRPIX2_COMMENT'} = "Reference Elevation Pixel";
  $img->fhdr->{'CROTA2'} = (234 - 15 + $rot);
  $img->fhdr->{'CROTA2_COMMENT'} = "Sky Angle";
} elsif ($sec =~ /MMIRS/) {
  $img->fhdr->{'EXPTIME_COMMENT'} = "Exposure time (seconds)";
  $img->fhdr->{'SEC'} = "F5 (MMIRS)";
  $img->fhdr->{'SEC_COMMENT'} = "Secondary Mirror";
  # set up the WCS headers
  $img->fhdr->{'CTYPE1'} = "LINEAR";
  $img->fhdr->{'CTYPE1_COMMENT'} = "Azimuth";
  $img->fhdr->{'CTYPE2'} = "LINEAR";
  $img->fhdr->{'CTYPE2_COMMENT'} = "Elevation";
  $img->fhdr->{'CDELT1'} = -1;
  $img->fhdr->{'CDELT1_COMMENT'} = "Azimuth Pixel Scale";
  $img->fhdr->{'CDELT2'} = 1;
  $img->fhdr->{'CDELT2_COMMENT'} = "Elevation Pixel Scale";
  $img->fhdr->{'CRVAL1'} = 255;
  $img->fhdr->{'CRVAL1_COMMENT'} = "Reference Azimuth";
  $img->fhdr->{'CRVAL2'} = 255;
  $img->fhdr->{'CRVAL2_COMMENT'} = "Reference Elevation";
  $img->fhdr->{'CRPIX1'} = 254;
  $img->fhdr->{'CRPIX1_COMMENT'} = "Reference Azimuth Pixel";
  $img->fhdr->{'CRPIX2'} = 255;
  $img->fhdr->{'CRPIX2_COMMENT'} = "Reference Elevation Pixel";
  $img->fhdr->{LTM1_1} = 1.0;
  $img->fhdr->{LTM2_2} = 1.0;
  $img->fhdr->{LTV2} = 0.0;
  $img->fhdr->{LTV1} = 0.0;
  $rotoff = $img->fhdr->{'ROTOFF'};
  $rot += $rotoff;
  $img->fhdr->{'CROTA2'} = (-83 + $rot);
  $img->fhdr->{'CROTA2_COMMENT'} = "Sky Angle";
} else {
  # exposure time
  $img->fhdr->{'EXPTIME'} = $exptime;
  $img->fhdr->{'EXPTIME_COMMENT'} = "Exposure time (seconds)";
  $img->fhdr->{'SEC'} = "F9";
  $img->fhdr->{'SEC_COMMENT'} = "Secondary Mirror";
  # set up the WCS headers
  $img->fhdr->{'CTYPE1'} = "LINEAR";
  $img->fhdr->{'CTYPE1_COMMENT'} = "Azimuth";
  $img->fhdr->{'CTYPE2'} = "LINEAR";
  $img->fhdr->{'CTYPE2_COMMENT'} = "Elevation";
  $img->fhdr->{'CDELT1'} = 1;
  $img->fhdr->{'CDELT1_COMMENT'} = "Azimuth Pixel Scale";
  $img->fhdr->{'CDELT2'} = 1;
  $img->fhdr->{'CDELT2_COMMENT'} = "Elevation Pixel Scale";
  $img->fhdr->{'CRVAL1'} = 254;
  $img->fhdr->{'CRVAL1_COMMENT'} = "Reference Azimuth";
  $img->fhdr->{'CRVAL2'} = 255;
  $img->fhdr->{'CRVAL2_COMMENT'} = "Reference Elevation";
  $img->fhdr->{'CRPIX1'} = 255;
  $img->fhdr->{'CRPIX1_COMMENT'} = "Reference Azimuth Pixel";
  $img->fhdr->{'CRPIX2'} = 255;
  $img->fhdr->{'CRPIX2_COMMENT'} = "Reference Elevation Pixel";
  $img->fhdr->{'CROTA2'} = 180 + (-225 + $rot);
  $img->fhdr->{'CROTA2_COMMENT'} = "Sky Angle";
}

# set up the FITS headers
$img->fhdr->{'BITPIX_COMMENT'} = "number of bits per data pixel";
$img->fhdr->{'NAXIS_COMMENT'} = "number of data axes";
$img->fhdr->{'NAXIS1_COMMENT'} = "length of data axis 1";
$img->fhdr->{'NAXIS2_COMMENT'} = "length of data axis 2";
$img->fhdr->{'RA'} = $data{'Right Ascension'};
$img->fhdr->{'RA_COMMENT'} = "Object RA";
$img->fhdr->{'DEC'} = $data{'Declination'};
$img->fhdr->{'DEC_COMMENT'} = "Object Dec";
$img->fhdr->{'EPOCH'} = "2000";
$img->fhdr->{'EPOCH_COMMENT'} = "Coordinate Epoch";
$img->fhdr->{'AZ'} = sprintf("%.2f", str2deg($data{'Azimuth'}, 'D'));
$img->fhdr->{'AZ_COMMENT'} = "Object Az at time of observation";
$img->fhdr->{'EL'} = sprintf("%.2f", str2deg($data{'Elevation'}, 'D'));
$img->fhdr->{'EL_COMMENT'} = "Object El at time of observation";
$img->fhdr->{'UT'} = $data{'UT'};
$img->fhdr->{'UT_COMMENT'} = "UT of observation";
$img->fhdr->{'LST'} = $data{'LST'};
$img->fhdr->{'LST_COMMENT'} = "Sidereal Time of observation";
$img->fhdr->{'HA'} = $data{'Hour Angle'};
$img->fhdr->{'HA_COMMENT'} = "Hour Angle of observation";
$img->fhdr->{'AIRMASS'} = sprintf("%.3f", $data{'Airmass'});
$img->fhdr->{'AIRMASS_COMMENT'} = "Secant of ZD of observation";
$img->fhdr->{'SECZ'} = sprintf("%.3f", $data{'Airmass'});
$img->fhdr->{'SECZ_COMMENT'} = "Secant of ZD of observation";
$img->fhdr->{'ROT'} = sprintf("%.3f", $rot);
$img->fhdr->{'ROT_COMMENT'} = "Instrument Rotator Angle";
$img->fhdr->{'PA'} = sprintf("%.3f", $data{'Parallactic Angle'});
$img->fhdr->{'PA_COMMENT'} = "Parallactic Angle";
$img->fhdr->{'CAT_ID'} = $data{'Object Name'};
$img->fhdr->{'CAT_ID_COMMENT'} = "Catalog Source Name";

$img->fhdr->{'WIND'} = sprintf("%.1f", $data{'Wind Speed'});
$img->fhdr->{'WIND_COMMENT'} = "Wind Speed (west sensor; mph)";
$img->fhdr->{'WINDDIR'} = sprintf("%d", $data{'Wind Direction'});
$img->fhdr->{'WINDDIR_COMMENT'} = "Wind Direction (west sensor)";
$img->fhdr->{'T_OUT'} = sprintf("%.1f", $data{'Outside Temperature C'});
$img->fhdr->{'T_OUT_COMMENT'} = 'Outside Temperature (C)';
$img->fhdr->{'T_CHAM'} = sprintf("%.1f", $data{'Chamber Temperature C'});
$img->fhdr->{'T_CHAM_COMMENT'} = 'Chamber Temperature (C)';
$img->fhdr->{'RH_OUT'} = sprintf("%.1f", $data{'Outside RH'});
$img->fhdr->{'RH_OUT_COMMENT'} = 'Outside RH';
$img->fhdr->{'RH_CHAM'} = sprintf("%.1f", $data{'Chamber RH'});
$img->fhdr->{'RH_CHAM_COMMENT'} = 'Chamber RH';
$img->fhdr->{'P_BARO'} = sprintf("%.1f", $data{'Barometric Pressure'});
$img->fhdr->{'P_BARO_COMMENT'} = 'Barometric Pressure';

$img->fhdr->{'TELNAME'} = "MMTO";
$img->fhdr->{'TELNAME_COMMENT'} = "Name of Observatory";
$img->fhdr->{'DATEOBS'} = $data{'Date'};
$img->fhdr->{'DATEOBS_COMMENT'} = "Date of observation";

# write the results back to input
$img->wfits("$ARGV[0]", '-32');

###########################################################

# open msg server socket and get a parameter from it.  this is a total
# hack of the msg_get command, but it seems to do the trick. 

sub msg_get {
  my $param = $_[0];
  my $socket = $_[1];
  print $socket "1 get $param\n";

  my @answer = split(' ', <$socket>);

  return $answer[2];
}

sub srv_lookup {
    my $service = $_[0];
    my $res = Net::DNS::Resolver->new;
    my $query = $res->query("_$service._tcp.mmto.arizona.edu", "SRV");

    if ($query) {
	foreach my $rr ($query->answer) {
	    next unless $rr->type eq "SRV";
	    $port = $rr->port;
	    $host = $rr->target;
	}
    } else {
	warn "query failed: ", $res->errorstring, "\n";
    }

    return ($host, $port);
}
