
package provide pmacserv 1.0
package require pmac 	 1.0

set done   0
set busy   0
set error  0

namespace eval pmacserv {
    namespace export {[a-z]*}

    variable Errors {
	"No Error"
	"ErrLimits"
	"ErrFolErr"
	"ErrRTError"
	"ErrNotRunning"
	"ErrStopLim"
	"ErrLimitAtHome"
	"ErrTimeout"
	"ErrNotHomed"
	"ErrEStop"
	"ErrServoPower"
	"ErrCNotOnFlag"
	"ErrTNotHomed"
	"ErrTNotCentered"
	"ErrBrakTimedOut"
	"ErrEncoderPower"
	"ErrProgramTimeout"
	"ErrMoveBeyondLimit"
    }

    proc stat { pmac names } {
	global done error

	pmac::stat $pmac $names

	if { [set err [pmac::pget $pmac error]] } {
	    set error $err
	}
	if { $done != [set don [pmac::pget $pmac done]] } {
	    set done  $don
	    set error $err
	}
    }

    proc run { pmac cs program } {
	pmac::comm $pmac "&${cs}#${cs}"
	pmac::comm $pmac "pmatch"
	pmac::comm $pmac "j/"
	pmac::comm $pmac "p94=1"
	pmac::comm $pmac "endg"
	pmac::comm $pmac "del gat"
	pmac::comm $pmac "def gat 6000"
	pmac::comm $pmac "gat"
	pmac::comm $pmac "gat"

	if { [pmac::comm $pmac m30] == 0 } {
	    error "ErrEStop"
	}
	pmac::comm $pmac "b${program}r"
    }

    proc wait { pmac N timeout } {
	variable Errors
	global   done error 

	set timeout_after [after [expr $timeout*1000] { pmac_timeout }]

	while { $done != $N } {
	    vwait error

	    if { $error } {
		after cancel $timeout_after
		error "Error in program : $error: [lindex $Errors $error]"
	    }
	}
	after cancel $timeout_after
    }

    proc proginit { pmac N } {
	    global done error busy

	    if { $busy } { error "pmac: server busy" }

	    set done  [pmac::pset $pmac done $N]
	    set error [pmac::pset $pmac error 0]
	    set busy  1
    }

    proc progdone { pmac cs } {
	global busy

	if { ![pmac::comm $pmac m$cs] } {
	    after 1000
	    pmac::comm $pmac "#${cs}K"
	}

	set busy 0
    }

    proc axishome { server pmac axis motor } {
	    msg_register $server ${axis}home 

	proc ::${axis}home { } [subst {
	    pmacserv::proginit $pmac 1

	    pmacserv::run  $pmac $motor 200$motor
	    pmacserv::wait $pmac 0 60

	    pmacserv::progdone $pmac $motor
	}]
	proc ::$server.${axis}home { s sock msgid cmd } [subst	{
	    ${axis}home
	    msg_ack \$sock \$msgid
	}]
    }

    proc axismove { server pmac axis motor } {
	    msg_register $server ${axis}move 
	    msg_publish  $server ${axis}offset ${axis}offset 
	    msg_publish  $server ${axis}offxxx ${axis}offxxx 

	    set ::${axis}offset 0.0
	    set ::${axis}offxxx 0.0

	proc ::${axis}move { position } [subst {
	    pmacserv::proginit $pmac 1

	    set position \
		\[expr \$position + \$::${axis}offset + \$::${axis}offxxx]

	    pmac::comm     $pmac "m${motor}00=\$position"
	    pmacserv::run  $pmac $motor "300$motor"
	    pmacserv::wait $pmac 0 60

	    pmacserv::progdone $pmac $motor
	}]
	proc ::$server.${axis}move { s sock msgid cmd position } [subst {
	    ${axis}move \$position
	    msg_ack \$sock \$msgid
	}]
    }

    proc axisbrak { server pmac axis motor } {
	    msg_register $server ${axis}brak

	proc ::${axis}brak { onoff } [subst {
    	    if { \$onoff == 1 } { pmac::comm 0 "m${motor}=1" 
	    } else {		  pmac::comm 0 "m${motor}=0" }
	}]
	proc ::$server.${axis}brak { s sock msgid cmd onoff } [subst {
	    ${axis}brak \$onoff
	    msg_ack \$sock \$msgid
	}]
    }

    proc init { server pmac axes motors } {
	pmac::init $pmac
	pmac::comm $pmac I9=2

	# Generic commands
	#
	msg_register $server  ACK
	msg_register $server  pmac
	msg_register $server  exit
	msg_register $server  value
	msg_register $server  abort
	msg_register $server  reset
	msg_register $server  clear
	msg_register $server  gather
	msg_register $server  gatdat

	pmacserv::axisbrak $server $pmac {} 7

	proc ::$server.ACK 	{ } { }
	proc ::$server.pmac 	{ s sock msgid cmd pmac command } {
	    if { [catch { set reply [pmac::comm $pmac $command] } reply] } {
		mag_nak $sock $msgid $reply 
	    } else {
		msg_ack $sock $msgid $reply 
	    }
	}
	proc ::$server.abort 	{ s sock msgid cmd pmac } {
		global busy
		pmac::comm $pmac "&1a#1k"
		pmac::comm $pmac "&2a#2k"
		pmac::comm $pmac "&3a#3k"
		pmac::comm $pmac "&4a#4k"
		set busy 0
		msg_ack $sock $msgid 
	}
	proc ::$server.clear 	{ s sock msgid cmd pmac } {
		global busy
		set busy 0
		msg_ack $sock $msgid 
	}
	proc ::$server.reset 	{ pmac } { pmac::comm $pmac {$$$}	}
	proc ::$server.clear 	{ } { }
	proc ::$server.gatdat 	{ s sock msgid cmd pmac } { 
		msg_ack $sock $msgid [pmacserv::gatdat $pmac]
	}

	foreach var {
		reset 
		busy
		state	
		mode
		stowed
		estop
		movetime
		servo
		Brak } {
	    msg_publish $server $var $var
	}

	foreach m { 11 12 13 14 15 16 20 24 25 26 31 80 } {
	    msg_publish $server m$m m$m "pmac_setvar $pmac m$m"
	}
	foreach i { 19 20 } {
	    msg_publish $server i$i i$i "pmac_setvar $pmac i$i"
	}
	foreach p { 70 71 72 73 74 75 } {
	    msg_publish $server p$p p$p "pmac_setvar $pmac p$p"
	}


	# Motor -- Axis commands
	#
	foreach a $axes m $motors {
	    # Axis control commands
	    #
	    pmacserv::axismove $server $pmac $a $m
	    pmacserv::axishome $server $pmac $a $m
	    pmacserv::axisbrak $server $pmac $a $m

	    foreach value {
		    A C T E DAC 
		    Homed HomePos PLimPos MLimPos Brak HFlag PLimit MLimit
		    PLim MLim VelZ IsMov StopLim FolErr InPos OLop
	    	    } {
		msg_publish $server $a$value $a$value 
	    }
	    msg_publish $server ${a}DACBias ${a}DACBias 	\
		"pmac_setdacbias $pmac $m ${a}DACBias"
	    

	    # Motor parameters and status
	    #
	    foreach i { 11 12 15 16 17 23 26 28 30 31
			32 33 34 35 63 64 65 67 68 69
			85 86 95 } {
		set var i$m[format %02d $i]
	    	msg_publish $server $var $var "pmac_setvar $pmac $var"
	    }
	    foreach p { 1 2 3 4 5 6 7 8 9 } {
		set var p${m}0$p
	        msg_publish $server $var $var "pmac_setvar $pmac $var"
	    }
	}

	return $pmac
    }

    proc gatdat { pmac } {
	set bits [pmac::comm $pmac i20]
	set data [pmac::comm $pmac "list gather"]
	pmac::comm $pmac "gather"

	regsub {\$} $bits 0x bits

	set axes 	{}
	set scal 	{}
	set bias 	{}

	array set AxisBits {
		 1	M
		 2	M
		 3	T
		 4	T
		 5	C
		 6	C
		 7	F
		 8	F
		 9	DAC
		10	DAC
		11	DAC
		12	DAC
	}

	array set Motor {
		DAC	5
		M	1
		T	2
		C	3	
		F	4
	}
	array set Scale {
		DAC	1
		M	 666.667
		T	1000
		C	2000
		F	2000
	}

	for { set bit 0 } { $bit < 14 } { incr bit } {
		set b [expr $bit+1]

		if { $bits & (1 << $bit) } {
		    set axis $AxisBits($b)
		    lappend axes $axis
		    lappend scal $Scale($axis)
		    lappend bias [pmac::comm $pmac "m$Motor($axis)14"]
		}
	}

	set values {}
	set axis    0


	foreach d $data {
		set top 0x[string range  $d 0  5]
		set bot 0x[string range  $d 6 12]

		if { $top & 0x800000 } { set top [expr $top | 0xFF000000] }

		set a [lindex $axes $axis]
		set s [lindex $scal $axis]
		set b [lindex $bias $axis]

	    if { $axis >= 8 } {
		if { $bot & 0x800000 } { set bot [expr $bot | 0xFF000000] }

		set s [expr 1.0/256.0 * 12.0/32768.0]

		lappend values [expr $bot * $s]
		lappend values [expr $top * $s]

	        incr axis; set axis [expr $axis % [llength $axes]]
	    } else {
		set p [expr ($top * 256.0*256.0* 256.0 + $bot + $b) /(32*96*$s)]
		lappend values $p
	    }
	    incr axis; set axis [expr $axis % [llength $axes]]
	}

puts ""
puts [lrange $data 0 23]
puts ""
puts ""
puts [lrange $values 0 23]
puts ""
	return $values
    }
}

proc pmac_setdacbias { pmac moto var name indx op } {
    global $var
    if { ![info exists $var] } {
	set $var [pmac::comm $pmac i${moto}29]
    }

    switch -exact -- $op {
	w {  pmac::comm $pmac i${moto}29=[set $var]] }
    }
}

proc pmac_setvar { pmac var name indx op } {
    global $var
    if { ![info exists $var] } {
	set $var [pmac::comm $pmac $var]
    }

    switch -exact -- $op {
	w {  pmac::comm $pmac $var=[set $var]] }
	r {  set $var [pmac::comm $pmac $var] }
    }
}

proc pmac_timeout { } {
    global error;  set error 16
}
