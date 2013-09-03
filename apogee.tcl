#!/usr/bin/wish

# This is a simple GUI script to acquire CCD images from an Apogee
# camera using the Dave Mills driver and SDK.  It takes exposure time,
# base filename, number of exposures, and a flag to tell it whether or
# not to generate header information using MSG calls to telserver.  It
# will check for existing files and increment the number in the
# filename accordingly so that nothing will be overwritten.
#
# TEP (4-7-2003)
#

set DEBUG 0

# make sure we actually have an apogee card...
set apogee "/dev/appci0"
if {![file exists $apogee]} {
    tk_messageBox -type ok -message "No Apogee camera is installed."
    exit
}

# look for DS9 and fire it up if it's not there
set x ""
catch {set x [exec xpaget ds9]}
if {$x == ""} {
    exec ds9 &
}

# set up MSG servers
set env(HEXSERV) hacksaw:5240
set env(TELESCOPE) hacksaw:5403
source /mmt/scripts/msg.tcl
msg_client HEXSERV
msg_client TELESCOPE

# set up image directory
set test ""
catch {set test $env(WFSROOT)}
if { $test == "" } {
    set data_dir "./"
} else {
    set data_dir "$env(WFSROOT)/datadir"
}

# not sure if this is really necessary, but can't hurt i guess.
global SCOPE CAMSTATUS CCAPI

# initialize the Mills driver stuff
set env(TKAPOGEE) /opt/apogee
set libs /opt/apogee/lib
load $libs/libfitsTcl.so
load $libs/libccd.so
source /opt/apogee/scripts/camera_init.tcl

# set up the GUI
wm title . "Apogee Camera Image Acquisition"
set guiframe [frame .ccdframe]

label $guiframe.dir -text "Image Directory:"
entry $guiframe.dir_entry -text data_dir

label $guiframe.name -text "Image Name:"
set fileroot "test"
entry $guiframe.name_entry -text fileroot

label $guiframe.exptime -text "Exposure Time:"
set exptime 0.1
entry $guiframe.exptime_entry -text exptime

label $guiframe.nexp -text "\# of Exposures:"
set nexp 1
entry $guiframe.nexp_entry -text nexp

set mode "MSG"
checkbutton $guiframe.usemsg -text "Put mount info in image header? " \
    -onvalue "MSG" -offvalue "TEST" -variable mode

button $guiframe.go -text "Get Images" -command {getImages}

grid configure $guiframe.dir  -column 0 -row 0 -sticky e
grid configure $guiframe.dir_entry  -column 1 -row 0 -sticky w
grid configure $guiframe.name -column 0 -row 1 -sticky e
grid configure $guiframe.name_entry -column 1 -row 1 -sticky w
grid configure $guiframe.exptime -column 0 -row 2 -sticky e 
grid configure $guiframe.exptime_entry -column 1 -row 2 -sticky w
grid configure $guiframe.nexp -column 0 -row 3 -sticky e
grid configure $guiframe.nexp_entry -column 1 -row 3 -sticky w
grid configure $guiframe.usemsg  -column 0 -row 4 -columnspan 2
grid configure $guiframe.go  -column 0 -row 5 -columnspan 2 -sticky news
pack $guiframe

proc getImages {} {
    global SCOPE CAMSTATUS CCAPI CAMERA DEBUG
    global mode nexp exptime fileroot data_dir

    if {![file isdirectory $data_dir]} {
	tk_messageBox -type ok -message "$data_dir does not exist or is not a directory."
	return
    }

    # i noticed stray charge would accumulate over time (or something like
    # that), but doing a flush before anything else cleared it up.  good
    # idea at any rate to always stick camera in the same state every
    # time.

    $CAMERA Flush
    exec sleep 1

    # loop through the number of exposures and take images accordingly
    for {set i 0} {$i < $nexp} {incr i 1} {

	set num 0
	set filename [format "%s/%s_%04d.fits" $data_dir $fileroot $num]

	# check for first unused file name and go with it
	while {[file exists $filename]} {
	    incr num 1
	    set filename [format "%s/%s_%04d.fits" $data_dir $fileroot $num]
	}
    
	# check the camera's status for debugging purposes
	set s [$CAMERA read_Status]
	puts stdout "Camera status before exposure is $s"

	# take the exposure (with the shutter open, of course)
	$CAMERA  Expose $exptime 1

	# make sure camera is exposing for debugging purposes
	set s [$CAMERA read_Status]
	puts stdout "Camera status during exposure is $s"

	# wait around for the exposure to finish before trying to read the
	# camera out
	exec sleep [expr 1.02*$exptime + 0.2]
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
	set SCOPE(exposure) $exptime
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

	write_calibrated READOUT $exptime $filename 0
	eval exec "xpaset -p ds9 file $filename"

    }

}

