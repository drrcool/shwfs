#!/usr/bin/tcl

set exposure [lindex $argv 0]
set fileroot [lindex $argv 1]
set nexp     [lindex $argv 2]

if {$argc != 3} {
     error "Usage: get_image_test.tcl <exposure time> <fileroot> <number of exposures"
}

global SCOPE CAMSTATUS CCAPI

set env(HEXSERV) hexapod:5350
set env(TELESCOPE) hacksaw:5403
source /mmt/scripts/msg.tcl
msg_client HEXSERV
msg_client TELESCOPE

set TKAPOGEE /opt/apogee
set libs /opt/apogee/lib

load $libs/libfitsTcl.so
load $libs/libccd.so

source /opt/apogee/scripts/camera_init.tcl

$CAMERA Flush
exec sleep 1

for {set i 0} {$i < $nexp} {incr i 1} {

    set num 0
    set filename [format "%s_%04d.fits" $fileroot $num]

    while {[file exists $filename]} {
	incr num 1
	set filename [format "%s_%04d.fits" $fileroot $num]
    }
    
    set s [$CAMERA read_Status]
    puts stdout "Camera status before exposure is $s"

    $CAMERA  Expose $exposure 1

    set s [$CAMERA read_Status]
    puts stdout "Camera status during exposure is $s"

    exec sleep [expr 1.02*$exposure + 1]
    $CAMERA  BufferImage READOUT

    set s [$CAMERA read_Status]
    puts stdout "Camera status after exposure is $s"

    set SCOPE(site) "Mt. Hopkins"
    set SCOPE(telescope) "MMT"
    set SCOPE(latitude) "31:41:20.5"
    set SCOPE(longitude) "110:53:04.5"
    set SCOPE(instrument) "SH WFS"
    set SCOPE(camera) "Apogee KX260e"
    set SCOPE(detector) "512x512"
    set SCOPE(observer) "T. E. Pickering"
    set SCOPE(target) [msg_get TELESCOPE cat_id]
    set SCOPE(exptype) "Object"
    set SCOPE(exposure) $exposure
    set SCOPE(darktime) 0.0
    set now [split [exec  date -u +%Y-%m-%d,%T] ,]
    set SCOPE(obsdate) [lindex $now 0]
    set SCOPE(obstime) [lindex $now 1]
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
