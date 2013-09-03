#!/usr/bin/tcl

set DEBUG 0

set mode     [lindex $argv 0]

set env(TKAPOGEE) /opt/apogee
set libs /opt/apogee/lib

load $libs/libfitsTcl.so
load $libs/libccd.so

source /opt/apogee/scripts/camera_init.tcl

set old_t [$CAMERA read_Temperature]

switch $mode {
    SET {
	$CAMERA write_CoolerMode 1
	set t [lindex $argv 1]
	if {$t > -40 && $t < 40} {
	    $CAMERA write_CoolerSetPoint $t
	    puts "Camera is currently at $old_t C, setting setpoint to $t C."
	} else {
	    puts "Setpoint out of -40 C to 40 C range."
	}
    }
    AMB {
	puts "Camera is currently at $old_t, setting it to track ambient temperature."
	$CAMERA write_CoolerMode 2
    }
    OFF {
	puts "Camera is currently at $old_t, turning cooler off."
	$CAMERA write_CoolerMode 0
    }
    CHECK {
	puts "Camera is currently at $old_t."
    }

}

