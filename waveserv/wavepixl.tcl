
set geometry +160+214

set env(WAVE) .:3003

source msg.tcl
source pixelink.tcl
source gui.tcl

set state   Video

msg_server   WAVE


set gain 10

msg_publish  WAVE state	   state 
msg_publish  WAVE gain	   gain  setgain

msg_register WAVE fits
msg_register WAVE read
msg_register WAVE exit

msg_allow WAVE {
	192.168.1.2	shadow	shadow.cfa.harvard.edu
			panic	panic.cfa.harvard.edu
			tdc 	tdc.cfa.harvard.edu
}

set bitpix	16

pixelink::init 0
pixelink::window 0 0 1280 1024 1
pixelink::gain   10
pixelink::expo   10

pixelink::mode   1
pixelink::stream 1
pixelink::pause  1
pixelink::size  $bitpix



#pixelink::mode    1
#pixelink::stream  1
#pixelink::pause   0 

proc setgain { name idex op } { 
	upvar $name value
	pixelink::gain $::gain
}

proc WAVE.setccd { s sock msgid cmd 					 \
	colbin xpreskip xunderscan xskip xdata xpostskip xoverscan dwell \
	rowbin ypreskip yunderscan yskip ydata ypostskip yoverscan split \
	nrvshift preflash						 \
} {
    pixelink::setccd							     \
    $colbin $xpreskip $xunderscan $xskip $xdata $xpostskip $xoverscan $dwell \
    $rowbin $ypreskip $yunderscan $yskip $ydata $ypostskip $yoverscan $split \
    $nrvshift $preflash	

    msg_ack $sock $msgid
}
msg_srvproc WAVE expose  { exptype exptime } { pixelink::expose still $exptime $::bitpix }
msg_srvproc WAVE binning { xbin ybin }       { pixelink::bin $xbin 		  }
msg_srvproc WAVE box     { x1 y1 xbin ybin } { pixelink::box $x1 $y1 $xbin $ybin  }

proc WAVE.fits { s sock msgid cmd nbytes } {
    senddata PIXEL $sock $msgid 0    $nbytes
}

proc WAVE.read { s sock msgid cmd nbytes } {
    senddata PIXEL $sock $msgid 2880 $nbytes
}

proc WAVE.exit { s sock msgid cmd } { exit }
proc WAVE.info { s sock msgid cmd } {
    set MsgCards 2

    msg_rpy $sock $msgid blk [expr 80 * $MsgCards]

    puts -nonewline $sock [fitscard CAMERA %32s MMTIPIXELINK]
    puts -nonewline $sock [binary format {A80} END]
    flush $sock
}

proc senddata { file sock msgid offset nbytes } {
    set fits [open $file.fit]
    fconfigure $fits -translation binary
    fconfigure $sock -translation binary
    seek $fits $offset

    set size [expr [file size $file.fit] - $offset]

    if { $nbytes == 0 || $size < $nbytes } {
	set nbytes $size
    }
    msg_rpy $sock $msgid blk $nbytes
    fcopy $fits $sock  -size $nbytes
    flush $sock

    close $fits
    fconfigure $sock -translation auto
}

msg_up    WAVE
vwait forever
