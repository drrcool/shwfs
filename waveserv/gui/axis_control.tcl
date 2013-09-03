# Axis Control Window
#

set limitcolors "green orange cyan red"
set troubcolors "red green red"

set Temps {
        mMTemp  hskT1   pwbTemp plusV12 minuV12 plusV05 vTemp   vLimit  
        tMTemp  hskT1   
        cMTemp  hskT1   
        fMTemp  hskT1   
        mSTemp  hskV1   
        tSTemp  hskV2  
        cSTemp  hskV3   
        fSTemp  ampTemp 
}

proc axis_control_sub { w } {
		global Temps
		global limitcolors

	msg_subscribe WAVESERV servo servo {} 				.2 20000
	msg_subscribe WAVESERV busy  busy  "updatebusy $w.busy"         .2
	msg_subscribe WAVESERV estop estop "updateestop $w.estop"	.2

	msg_subscribe WAVESERV Brak Brak "brakstat {}"		.2

	msg_subscribe WAVESERV spower spower "updatebit .power.spower red green"
	msg_subscribe WAVESERV epower epower "updatebit .power.epower red green"
	msg_subscribe WAVESERV ppower ppower "updatebit .power.ppower red green"
	msg_subscribe WAVESERV apower apower "updatebit .power.apower red green"
	msg_subscribe WAVESERV bpower bpower "updatebit .power.bpower red green"
	msg_subscribe WAVESERV fpower fpower "updatebit .power.fpower red green"

	foreach axis { m t c f } {
	    foreach value { A C T E } {
	        msg_subscribe WAVESERV $axis$value $axis$value {vformat "%8.3f"} .2
	    }

	    msg_subscribe WAVESERV ${axis}Brak ${axis}Brak "brakstat $axis" .2

	    msg_subscribe WAVESERV ${axis}OLop ${axis}OLop \
		    "updateolop   $w.l${axis}" 				.2
	    msg_subscribe WAVESERV ${axis}PLimit ${axis}PLimit \
		    "updateclrbit $w.${axis}PLimit [list $limitcolors]"	.2
	    msg_subscribe WAVESERV ${axis}MLimit ${axis}MLimit \
		    "updateclrbit $w.${axis}MLimit [list $limitcolors]"	.2

	    msg_subscribe WAVESERV ${axis}offset ${axis}offset
	    msg_subscribe WAVESERV ${axis}offxxx ${axis}offxxx
	}

	foreach temp $Temps {
	    msg_subscribe WAVESERV $temp $temp {} 1
	}

	msg_subscribe WAVESERV cpuTemp cpuTemp

	msg_subscribe WAVESERV pA    pA
	msg_subscribe WAVESERV pT    pT
	msg_subscribe WAVESERV pLite pLite litestat
}

proc axis_control { w } {

    Grid [axis_pbox [frame $w.control]] -
    axis_control_sub $w.control

    return $w
}

proc axis_pbox { w } {

  Grid												\
    [label  $w.l -text "WAVESERV" -background yellow] 					 -	\
    [button $w.abort -text "Abort" -background lightblue -command [list msg_cmd WAVESERV "abort 0"]] - \
    [button $w.clear -text "Clear" -background lightblue -command [list msg_cmd WAVESERV "clear 0"]] - \
    [label  $w.busy  -text Idle  -width 8 -relief groove]				 -	\
    [label  $w.estop -text EStop -relief groove] 					 - 	\
    [button $w.power -text Power -command power]					 -

  Grid										\
    [label  $w.sele -text "Select" -justify right -anchor e]		- 	\
    [button $w.swfs -text WFS     -command selwfs]			-	\
    [button $w.ssci -text SciCam  -command selsci]			-	\
    [button $w.home -text Home  -command [list askto . home "Do you want to home the WFS"]]	-	\
    [button $w.stow -text Stow  -command [list askto . stow "Do you want to stow the WFS"]]	-	\
    [button $w.cam  -text Camera -command camera]			-

  Grid										\
    [label  $w.ltarc  -text "Field Angle" -justify right -anchor e]	- -	\
    [entry  $w.tarc   -textvariable TArc -width 8 -justify right]	-	\
    [label  $w.larc   -text {"} -anchor w]					\
    [button $w.tposi  -text Go  -command tposi]					\
    [checkbutton $w.slew -text Slew -variable slew -command slew] 	-

  Grid										\
    [label  $w.ltpos -text "Off Axis Pos" -justify right -anchor e]	- -	\
    [entry  $w.tpos  -textvariable TPos -width 8 -justify right]	-	\
    [label  $w.tmm   -text mm -anchor w]					\
    [button $w.trans -text Go -command trans]					\
    [entry  $w.toff  -textvariable toffset -width 5 -justify right]		\
    [entry  $w.txxx  -textvariable toffxxx -width 5 -justify right -state disabled]		\
    [label  $w.lpunt -text Puntino]					-	\
    [button $w.phome -text PHome -command phome]			-

  Grid										\
    [label  $w.lmpos  -text "Mirror Pos" -justify right -anchor e]	- -	\
    [entry  $w.mpos   -textvariable MDeg -width 8 -justify right]	-	\
    [label  $w.mdeg   -text deg -anchor w]					\
    [button $w.mirror -text Go -command mirror]					\
    [entry  $w.moff   -textvariable moffset -width 5 -justify right]		\
    [entry  $w.mxxx   -textvariable moffxxx -width 5 -justify right -state disabled]		\
    [button $w.litein -text "Ref Pos" -command callite]			-	\
    [button $w.liteot -text "Sky Pos" -command xmirror]			-

  Grid										\
    [label  $w.fmpos  -text "Focus Pos" -justify right -anchor e]	- -	\
    [entry  $w.fpos   -textvariable FPos -width 8 -justify right]	-	\
    [label  $w.fmm    -text mm -anchor w]					\
    [button $w.focus  -text Go -command xfocus]				\
    [entry  $w.foff   -textvariable foffset -width 5 -justify right]		\
    [entry  $w.fxxx   -textvariable foffxxx -width 5 -justify right -state disabled]		\
    [button $w.pw     -text "Plot"   -command axis_PW]			-	\
    [button $w.mstatus -text "Status" -command "mstatus"]		-

  Grid 								 				  \
    [entry $w.servo -textvariable servo -state disabled -relief groove -justify right -width 6] - \
    [button $w.lm -text "Mirror" -command [list axis_TW 1 m]] -	\
    [button $w.lt -text "Trans"  -command [list axis_TW 2 t]] -	\
    [button $w.lc -text "Select" -command [list axis_TW 3 c]] -	\
    [button $w.lf -text "Focus"  -command [list axis_TW 4 f]] -	\
    [button $w.lp -text "Punt"   -background lightblue]          	 		 -

  Grid   								\
    [label $w.actual  -text "Actual" -justify right -anchor e]      -	\
    [entry $w.mA -textvariable mA -justify right -width 8] 	    - 	\
    [entry $w.tA -textvariable tA -justify right -width 8] 	    - 	\
    [entry $w.cA -textvariable cA -justify right -width 8] 	    -	\
    [entry $w.fA -textvariable fA -justify right -width 8] 	    -	\
    [entry $w.pA -textvariable pA -justify right -width 8]	    -	\
    x x

  Grid   								\
    [label $w.command  -text "Commanded" -justify right -anchor e] -  	\
    [entry $w.mC  -textvariable mC  -justify right -width 8] 	   - 	\
    [entry $w.tC  -textvariable tC  -justify right -width 8] 	   - 	\
    [entry $w.cC  -textvariable cC  -justify right -width 8] 	   - 	\
    [entry $w.fC  -textvariable fC  -justify right -width 8] 	   - 	\
    x x 								\
    x x 

  Grid   								\
    [label $w.machin  -text "Target" -justify right -anchor e] -	\
    [entry $w.mE -textvariable mT  -justify right -width 8] - 		\
    [entry $w.tE -textvariable tT  -justify right -width 8] - 		\
    [entry $w.cE -textvariable cT  -justify right -width 8] - 		\
    [entry $w.fE -textvariable fT  -justify right -width 8] - 		\
    [entry $w.pE -textvariable pT  -justify right -width 8] - 		\
    x x 

  Grid 									\
    [button $w.brak							\
	    -textvariable brak -background lightblue			\
	    -command  "setbrake {}"] -					\
    [button $w.xbrak							\
	    -textvariable mbrak -background lightblue			\
	    -command  "setbrake m"] -					\
    [button $w.mbrak							\
	    -textvariable tbrak -background lightblue			\
	    -command  "setbrake t"] -					\
    [button $w.fbrak							\
	    -textvariable cbrak -background lightblue			\
	    -command  "setbrake c"] -					\
    [button $w.cbrak							\
	    -textvariable fbrak -background lightblue			\
	    -command  "setbrake f"] -					\
    [button $w.plite							\
	    -textvariable plite -background lightblue			\
	    -command  "plite"] -


Grid x x 						 	 		\
    [label $w.mPLimit -text "+L" -width 4 -relief groove]			\
    [label $w.mMLimit -text "-L" -width 4 -relief groove]			\
    [label $w.tPLimit -text "+L" -width 4 -relief groove]			\
    [label $w.tMLimit -text "-L" -width 4 -relief groove]			\
    [label $w.cPLimit -text "+L" -width 4 -relief groove]			\
    [label $w.cMLimit -text "-L" -width 4 -relief groove]			\
    [label $w.fPLimit -text "+L" -width 4 -relief groove]			\
    [label $w.fMLimit -text "-L" -width 4 -relief groove]			\
    x x x x x x

Grid 	[label $w.wfstemp -text "Temperatures" -background yellow] 	 - - x	\
	x x									\
	[label $w.cputemp -text "CPU" -justify right -anchor e]    	 -	\
    	[entry $w.cpuTemp -textvariable cpuTemp -justify right -width 8] -
	
Grid 	[label $w.tpmotor -text "Motor"] -					\
    	[entry $w.mMTemp -textvariable mMTemp -justify right -width 8] - 	\
    	[entry $w.tMTemp -textvariable tMTemp -justify right -width 8] - 	\
    	[entry $w.cMTemp -textvariable cMTemp -justify right -width 8] - 	\
    	[entry $w.fMTemp -textvariable fMTemp -justify right -width 8] - 
Grid 	[label $w.tpstruc -text "Struct"] -					\
    	[entry $w.mSTemp -textvariable mSTemp -justify right -width 8] - 	\
    	[entry $w.tSTemp -textvariable tSTemp -justify right -width 8] - 	\
    	[entry $w.cSTemp -textvariable cSTemp -justify right -width 8] - 	\
    	[entry $w.fSTemp -textvariable fSTemp -justify right -width 8] - 

	return $w
}

proc vformat { format name indx op } {
	upvar $name var

	if { [string compare $var "NaN"] } {
	    set var [format $format $var]
	}
}

proc updatelabel { w list name indx op } {
	upvar $name var

	if { $var >= [llength $list] } {
		$w configure -text [lindex $list end]
	} else {
		$w configure -text [lindex $list $var]
	}
}

proc updateclrbit { w color name indx op } {
	upvar $name var

	catch { $w configure -background [lindex $color $var] }
}

proc asktogglepow { power name } {
	upvar #0 $power pow

    if { $pow } {
        askto .power "togglepow $power" "Do you want to turn \n$name power OFF"
    } else {
        askto .power "togglepow $power" "Do you want to turn \n$name power ON"
    }
}

proc togglepow { power } {
	upvar #0 $power pow

	msg_cmd WAVESERV "$power [expr !$pow]" 13000
}

proc updatebit { w off on name indx op } {
	upvar $name var

    if { $var == 0 } {
	    catch { $w configure -background $off }
    } else {
	    catch { $w configure -background $on  }
    }
}

proc updateolop { w name indx op } {
	upvar $name var

	updatebit   $w  green      red     var $indx $op
}
proc updateestop { w name indx op } {
	upvar $name var

	updatelabel $w {"EStop " "OK    "}  var $indx $op
	updatebit   $w red  green  var $indx $op
}

proc updatebusy { w name indx op } {
	upvar $name var

	updatelabel $w {"Idle  "   "Busy  "} var $indx $op
	updatebit   $w green  red  var $indx $op
}

proc setbrake { axis } {
    upvar #0 ${axis}brak brak

    if { ![string compare $axis {}] } {
	set text "BrkAuto"
    } else {
	set text Held
    }

    if { ![string compare $brak $text] } {
	msg_cmd WAVESERV "${axis}brak 1"
    } else {
	msg_cmd WAVESERV "${axis}brak 0"
    }
}

proc phome { } { msg_cmd WAVESERV "phome" 30000 }
proc plite { } {
	global pLite

    msg_cmd WAVESERV "plite [expr !$pLite]"
}

proc litestat { name indx mode } {
	global pLite
	global plite

    if { $pLite } {
	set plite "Lite On "
    } else {
	set plite "Lite Off"
    }
}

proc brakstat { axis name indx mode } {
	upvar #0 ${axis}Brak	brak
	upvar #0 ${axis}brak 	text

    if { ![string compare ${axis} {}] } {
	if { $brak } {
		set text "BrkMan "
	} else {
		set text "BrkAuto"
	}
    } else {
	if { $brak } {
		set text Free
	} else {
		set text Held
	}
    }
}

proc camera { } {

    ToplevelRaise .camera
}

proc power { } {

    if { [winfo exists .power] } {
        ToplevelRaise .power
	return
    }

    set w [toplevel .power]

  Grid 			 							\
    [label  $w.lpower -text "WFS Power" -justify right -anchor e -background yellow] 		-	\
    [button $w.spower -text "Servo"   -command "asktogglepow spower Servo"]	-	\
    [button $w.epower -text "Encoder" -command "asktogglepow epower Encoder"] 	-	\
    [button $w.ppower -text "Puntino" -command "asktogglepow ppower Puntino"] 	-

  Grid										\
    x x										\
    [button $w.bpower -text "SBIG"    -command "asktogglepow bpower SBIG"]	-	\
    [button $w.apower -text "Apogee"  -command "asktogglepow apower Apogee"] 	-	\
    [button $w.fpower -text "Filters" -command "asktogglepow fpower Filter"]	-

    global spower epower ppower bpower apower fpower
    set spower $spower
    set epower $epower
    set ppower $ppower
    set apower $apower
    set bpower $bpower
    set fpower $fpower
}

