#!/data/mmti/bin/wish

lappend auto_path /data/mmti/tcl

option add *background 	white
option add *foreground 	black
option add *font	default

package require Memchan

font create default -family Courier -size 12 -weight bold 

#namespace import blt::*

#set env(WAVESERV) wavefront:3000

source ../msg.tcl
source ../bob.tcl
source ../try.tcl

source /data/mmti/src/mmtitcl/handy.tcl
source /data/mmti/src/mmtitcl/ent.tcl
source /data/mmti/src/mmtitcl/shm.tcl

source ./axis_control.tcl
source ./axis_tweak.tcl
source ./axis_plot.tcl
source ./mstatus.tcl

source ./camconf.tcl
source ./camera.tcl
source ./camdisp.tcl
#vwait forever

set PuntinoCal	  1
set PuntinoSky	620

msg_client WAVESERV

Toplevel . "WAVESERV Motion Control" -0+0
Grid [axis_control [frame .axis_control]]

proc home { } {
	msg_cmd    WAVESERV home 120000
}

proc stow { } {
	msg_cmd    WAVESERV stow  60000
}

proc callite { } {
	msg_cmd    WAVESERV "pmove $::PuntinoCal" 30000
	msg_cmd    WAVESERV "plite 1" 		   3000
}

proc xmirror { } {
	msg_cmd    WAVESERV "pmove $::PuntinoSky" 30000
	msg_cmd    WAVESERV "plite 0" 		   3000
}

proc uformat { format name indx op } {
	upvar $name var

	global WAVESERV

    if { [string compare $WAVESERV(setting) {}] } {
	if { [string compare $var "NaN"] } {
	    set var [format $format $var]
	}
    }
}

msg_subscribe WAVESERV MDeg MDeg {uformat "%8.3f"}
msg_subscribe WAVESERV TPos TPos {uformat "%8.3f"}
msg_subscribe WAVESERV FPos FPos {uformat "%8.3f"}

set MDeg 0
set TArc 0
set TPos 0
set FPos 0

proc offsets { } {
	msg_set WAVESERV toffset $::toffset
	msg_set WAVESERV moffset $::moffset
	msg_set WAVESERV foffset $::foffset
}

proc tposi  { } { offsets; msg_cmd WAVESERV "tposi $::TArc" 60000 }
proc trans  { } { offsets; msg_cmd WAVESERV "tmove $::TPos" 60000 }
proc mirror { } { offsets; msg_cmd WAVESERV "mposi $::MDeg" 30000 }
proc xfocus { } { offsets; msg_cmd WAVESERV "fmove $::FPos" 60000 }
proc slew   { } { msg_set WAVESERV slew $::slew }

proc selwfs { } {
	msg_cmd    WAVESERV "select wfs" 30000
}

proc selsci { } {
	msg_cmd    WAVESERV "select sci" 30000
}

proc askto { w what mess } {
    if { ![string compare 								\
		[tk_messageBox -parent $w -default no -icon warning -message $mess -type yesno]	\
		yes] } {
	eval $what
    }
}
