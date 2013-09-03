#!/usr/bin/tcl

set exposure [lindex $argv 0]
set fileroot [lindex $argv 1]
set nexp     [lindex $argv 2]

if {$argc != 3} {
     error "Usage: get_image_test.tcl <exposure time> <fileroot> <number of exposures"
}

global SCOPE CAMSTATUS CCAPI

set TKAPOGEE /opt/apogee
set libs /opt/apogee/lib

load $libs/libfitsTcl.so
load $libs/libccd.so

source /opt/apogee/scripts/camera_init.tcl

$CAMERA Flush

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
    set SCOPE(target) "Test Image"
    set SCOPE(exptype) "Object"
    set SCOPE(exposure) $exposure
    set SCOPE(darktime) 0.0
    set now [split [exec  date -u +%Y-%m-%d,%T] ,]
    set SCOPE(obsdate) [lindex $now 0]
    set SCOPE(obstime) [lindex $now 1]
    set SCOPE(equinox) "J2000"
    set SCOPE(ra) "00:00:00.0"
    set SCOPE(dec) "00:00:00.0"
    set SCOPE(az) "180.0"
    set SCOPE(el) "90.0"
    set SCOPE(ha) "00:00:00.0"
    set SCOPE(lst) "00:00:00.0"
    set SCOPE(secz) "1.0"
    set SCOPE(focus) "0.0"
    set SCOPE(rot) "0.0"
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

