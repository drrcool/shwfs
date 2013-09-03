#!/usr/bin/tcl

# This is a simple command-line script to acquire CCD images from an
# Apogee camera using the Dave Mills driver and SDK.  It takes
# exposure time, base filename, number of exposures, and a flag to
# tell it whether or not to generate header information using MSG
# calls to telserver.  It will check for existing files and increment
# the number in the filename accordingly so that nothing will be
# overwritten.
#
# TEP (4-7-2003)
#

set exposure [lindex $argv 0]
set fileroot [lindex $argv 1]
set nexp     [lindex $argv 2]
set mode     [lindex $argv 3]

# tcl is not very graceful about dying with errors.....
if {$argc != 4} {
     error "Usage: get_image.tcl <exposure time> <fileroot> <number of exposures> <MSG|TEST>"
}

# look for DS9 and fire it up if it's not there
set x ""
catch {set x [exec xpaget ds9]}
if {$x == ""} {
    exec ds9 &
}

# not sure if this is really necessary, but can't hurt i guess.
global SCOPE CAMSTATUS CCAPI

# if we're in MSG mode, connect to the appropriate servers
if {$mode == "MSG"} {
    set env(HEXSERV) hexapod:5350
    set env(TELESCOPE) hacksaw:5403
    source /mmt/scripts/msg.tcl
    msg_client HEXSERV
    msg_client TELESCOPE
}

# initialize the Mills driver stuff
set TKAPOGEE /opt/apogee
set libs /opt/apogee/lib
load $libs/libfitsTcl.so
load $libs/libccd.so
source /opt/apogee/scripts/camera_init.tcl

# i noticed stray charge would accumulate over time (or something like
# that), but doing a flush before anything else cleared it up.  good
# idea at any rate to always stick camera in the same state every
# time.

$CAMERA Flush
exec sleep 1

# loop through the number of exposures and take images accordingly
for {set i 0} {$i < $nexp} {incr i 1} {

    set num 0
    set filename [format "%s_%04d.fits" $fileroot $num]

    # check for first unused file name and go with it
    while {[file exists $filename]} {
	incr num 1
	set filename [format "%s_%04d.fits" $fileroot $num]
    }
    
    # check the camera's status for debugging purposes
    set s [$CAMERA read_Status]
    puts stdout "Camera status before exposure is $s"

    # take the exposure (with the shutter open, of course)
    $CAMERA  Expose $exposure 1

    # make sure camera is exposing for debugging purposes
    set s [$CAMERA read_Status]
    puts stdout "Camera status during exposure is $s"

    # wait around for the exposure to finish before trying to read the
    # camera out
    exec sleep [expr 1.02*$exposure + 1]
    $CAMERA  BufferImage READOUT

    # make sure the camera is done reading out for debugging purposes
    set s [$CAMERA read_Status]
    puts stdout "Camera status after exposure is $s"

    # now define the header entries that will go in the FITS image
    set SCOPE(site) "Mt. Hopkins"
    set SCOPE(telescope) "MMT"
    set SCOPE(latitude) "31:41:20.5"
    set SCOPE(longitude) "110:53:04.5"
    set SCOPE(instrument) "SH WFS"
    set SCOPE(camera) "Apogee KX260e"
    set SCOPE(detector) "512x512"
    set SCOPE(observer) "T. E. Pickering"
    if {$mode == "MSG"} {
	set SCOPE(target) [msg_get TELESCOPE cat_id]
    } else {
	set SCOPE(target) "test exposure"
    }
    set SCOPE(exptype) "Object"
    set SCOPE(exposure) $exposure
    set SCOPE(darktime) 0.0
    set now [split [exec  date -u +%Y-%m-%d,%T] ,]
    set SCOPE(obsdate) [lindex $now 0]
    set SCOPE(obstime) [lindex $now 1]
    if {$mode == "MSG"} {
	set SCOPE(equinox) [msg_get TELESCOPE epoch]
	set SCOPE(ra) [msg_get TELESCOPE ra]
	set SCOPE(dec) [msg_get TELESCOPE dec]
	set SCOPE(az) [msg_get TELESCOPE az]
	set SCOPE(el) [msg_get TELESCOPE el]
	set SCOPE(ha) [msg_get TELESCOPE ha]
	set SCOPE(lst) [msg_get TELESCOPE lst]
	set SCOPE(secz) [msg_get TELESCOPE airmass]
	set SCOPE(focus) [msg_get TELESCOPE focus]
	set SCOPE(rot) [msg_get TELESCOPE rot]
    } else {
	set SCOPE(equinox) "J2000"
	set SCOPE(ra) "00:00:00.0"
	set SCOPE(dec) "00:00:00.00"
	set SCOPE(az) "180.0"
	set SCOPE(el) "90.0"
	set SCOPE(ha) "00:00:00.0"
	set SCOPE(lst) "00:00:00.0"
	set SCOPE(secz) "1.0"
	set SCOPE(focus) "0.0"
	set SCOPE(rot) "0.0"
    }
    set SCOPE(filterpos) 1
    set SCOPE(filtername) "clear"
    set SCOPE(shutter) 1

    set CAMSTATUS(CoolerMode) $CCAPI(CoolerMode)
    set t [$CAMERA read_Temperature]
    set CAMSTATUS(Temperature) $t
    set CAMSTATUS(BinX) $CCAPI(BinX)
    set CAMSTATUS(BinY) $CCAPI(BinY)
    set CAMSTATUS(Gain) 8.0

    write_calibrated READOUT $exposure $filename 0
    eval exec "xpaset -p ds9 file $filename"

}
