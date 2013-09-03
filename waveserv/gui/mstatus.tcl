
    set mstatus1 {
	"Motor Activated"	 "Negative Limit Set" 	"Positive Limit Set" 	"Skip"
	"Skip" 			"Open Loop" 		"Running Move" 		"Skip"
	"Dwelling" 		"Data Block Error" 	"Desired Vel is Zero" 	"Abort Deceleration"
	"Skip"			"Home in Progress" 	"Skip" 			"Skip"
	"Skip" 			"Skip" 			"Skip" 			"Skip"
	"Skip" 			"Skip" 			"Skip" 			"Skip"
    }

    set mstatus2 {
	"Assigned To CS" 	"Skip" 			"Skip" 			"Skip"
	"Skip" 			"Skip" 			"Skip" 			"Skip"
	"Skip" 			"Amp Enabled" 		"Skip" 			"Skip"
	"Stoped on Limit" 	"Home Complete" 	"Skip" 			"Skip"
	"Skip" 			"Skip" 			"Skip" 			"Skip"
	"Amp Fault" 		"Following Error" 	"Following Warning" 	"In Position"
    }

proc mstatus { } {
    if { [winfo exists .mstatus] == 0 } {
	mstatus_box [Toplevel .mstat "Motor/Servo Status" +0+0]
    }
    ToplevelRaise .mstat
}


proc checkmstatus { n axis name indx op } {

    upvar #0  mstatus$n mstatus 
    upvar     $name      status

    set i 0
    foreach bit $mstatus {
	if { [string compare $bit Skip] } {
	    global $axis$n$bit

    	    set c 0x[string index [format %06x $status] [expr $i / 4]]
    	    set $axis$n$bit	[expr !!($c & (1 << [expr 3 - $i % 4]))]
	}
	incr i
    }
}

proc mstatus_box { w } {
	global mstatus

    set row [label $w.space1]
    foreach axis { X F M C } {
	global ${axis}status1
	global ${axis}status2

#    	msg_subscribe WAVESERV ${axis}status1 ${axis}status1 "checkmstatus 1 $axis"
#    	msg_subscribe WAVESERV ${axis}status2 ${axis}status2 "checkmstatus 2 $axis"
	set row "$row [label $w.l$axis -text $axis]"
    }
    eval grid $row -sticky news

    buildbits 1 $w
    buildbits 2 $w
}

proc buildbits { n w } {
	upvar #0 mstatus$n mstatus 

    set i 0
    foreach bit $mstatus {
	if { [string compare $bit Skip] } {
		set row [label $w.m${n}bit$i -text $bit -justify left -anchor w]

	    foreach axis { X M F C } {
		global $axis$n$bit
		set row "$row [checkbutton $w.box$axis$n$i -variable $axis$n$bit]"
	    }
	}
	eval grid $row -sticky news
	incr i
    }
}
