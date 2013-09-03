# Axis Tweak Dialogs

set period 5

set RRY 100

proc fraction { name indx op } {
	upvar $name var

    if { $op == r } {
	set var [expr $var/0x7FFFFF]
	vformat "%8.2" var {} $op
    }
    if { $op == w } {
	set var [expr 0x7FFFFF*$var]
    }
}


set column1 {
mtcf	 x	x				space0	     	x	x
mtcf	 O	"Encoder Scale"			${axis}E  	counts/mm	%8.3f

mtcf	 O	"Limit of Pos. Travel"		${axis}MLimPos	mm	%8.3f
mtcf	 O	"Limit of Neg. Travel"		${axis}PLimPos	mm	%8.3f
mtcf	 O	"Encoder Home At"		${axis}HomePos	mm	%8.3f
mtcf	 x	x				space1	     	x	x
x	 0	"DAC Value"			${axis}DAC	bits	"%d"
x	 IO	"DAC Bias"			${axis}DACBias	bits	"%d"

g	 O	"dbg1"				dbg1		""	%8.3f
g	 O	"dbg2"				dbg2		""	%8.3f
g	 O	"dbg3"				dbg3		""	%8.3f

g	 O	"dbg4"				dbg4		""	%8.0f
g	 O	"dbg5"				dbg5		""	%8.0f
g	 O	"dbg6"				dbg6		""	%8.0f


c	 IO	"WFS Position"			p70		mm	%8.3f
c	 IO	"Sci Position"			p71		mm	%8.3f

t	 IO 	"WFS T Offset"			p72		mm	%8.3f
t	 IO 	"Sci T Offset"			p73		mm	%8.3f

f	 IO 	"WFS F Offset"			p74		mm	%8.3f
f	 IO 	"Sci F Offset"			p75		mm	%8.3f
}

set column2 {
xmfc	x 	x 				space0	   x 		x

mtcf   IO	"Proportional Gain"		i${moto}30 ""		%8.0f
mtcf   IO	"Derivitive Gain"		i${moto}31 ""		%8.0f
mtcf   IO	"Velocity Feed Forward"		i${moto}32 ""		%8.0f
mtcf   IO	"Integral Gain" 		i${moto}33 ""		%8.0f
mtcf   IO	"Integral Mode" 		i${moto}34 ""		%8.0f

mtcf   IO	"Integration Limit"		i${moto}63 "1/16 count"	%8.0f
mtcf   IO	"Big Step Limit"		i${moto}67 "1/16 count" %8.0f

mtcf	x 	x 				space1	   x		x

mtcf   IO	"Feed Rate" 			p${moto}05 "mm/sec"	%8.3f
mtcf   IO	"Time of Acceleration" 		p${moto}06 "msec" 	%8.0f
mtcf   IO	"Time of S-Curve" 		p${moto}07 "msec"	%8.0f
mtcf   IO	"Home Speed" 			p${moto}02 "mm/sec"	%8.3f
mtcf   IO	"Home Offset" 			p${moto}03 "mm"		%8.3f
mtcf   IO	"Maximum Velocity" 		i${moto}16 "counts/msec"  %8.3f
mtcf   IO	"Maximum Acceleration" 		i${moto}17 "counts/msec2" %8.3f
mtcf   IO	"Position Tolerance" 		p${moto}08 "mm" 	%8.3f
mtcf   IO	"Following Error" 		i${moto}11 "1/16 count"	%8.0f
mtcf   IO	"Hold Decel Rate" 		i${moto}95 "2^-23msec/servo" %8.0f
mtcf   IO	"Error Deceleration Rate" 	i${moto}15 "counts/msec2" %8.0f
x      IO	"Dead Band Factor"		i${moto}64 ""		%8.0f
x      IO	"Dead Band Size"		i${moto}65 "1/16 counts"	%8.0f
}

proc axis_TW { label axis } {
    if { [winfo exists .axis_tweak${axis}] == 0 } {
	axis_tweak [Toplevel .axis_tweak${axis}			\
		"$label $axis Axis Tweak" +100+100] $axis
    }
    ToplevelRaise .axis_tweak${axis}
}

array set AxisMap {
    m	1
    t	2
    c	3
    f	4
}

proc buildcolumn { column w axis } {
	global AxisMap

    set moto $AxisMap($axis)

    foreach { axes io name vari units format } $column {
	if { [string first $axis $axes] == -1 } { continue }
        if { [string compare $name x] == 0 } 	{
		 Grid [label $w.${vari}] x x
		 continue
	}

	eval set  vname ${vari}
        global   $vname
        upvar #0 $vname var

        if { [info exists var] == 0 } { set $vname 0 }

        if { [string first I ${io}] != -1 } {
		catch {
	       set val {}
	       set val [msg_get WAVESERV $vname]
	    }

	       set $vname $val

	    eval Grid [msgentry WAVESERV $name $w.$vname {} Server {} {} {} -width 8] \
		  [label $w.lu_$vname -text $units -anchor w] 
	} else {
	    eval Grid [labentry         $name $w.$vname -width 8 -state disabled] \
		  [label $w.lu_$vname -text $units -anchor w] 
	}

        if { [string first O ${io}] != -1 } {
	    msg_subscribe WAVESERV $vname $vname "vformat $format" {} 30000 column
        }
    }
}

proc axis_tweak { w axis } {

Grid [InFrame $w.f1 {
	upvar 	axis	axis

    Grid [InFrame $w.move {
		upvar 	axis	axis

		global ${axis}_left
		global ${axis}_right 
	        global ${axis}brake

	 Grid [button $w.cloop -text "Close Loop" -command [list cloop $axis]]		\
	      [button $w.abort -text "Abort"      -command [list msg_cmd WAVESERV "abort"]]	\
	      [button $w.home  -text "Home"       -command [list msg_cmd WAVESERV ${axis}home 60000]]

	 if { ![string compare $axis c] } {
	     set ctags [button $w.ctags -text "Tag Up"     -command [list msg_cmd WAVESERV "ctags"]]
	 } else {
	     set ctags {}
	 }

	 eval Grid [button $w.${axis}brak			\
		    -textvariable ${axis}brak			\
		    -command  "setbrake $axis"]			\
		    $ctags

	set movelab "mm"

	eval Grid [button $w.goleft  -text "Move To" -command [list moveto $axis left]] 	\
		  [entry $w.left  -justify right -width 8 -textvariable ${axis}_left]   \
		  [label $w.rul -text $movelab -anchor w]

	eval Grid [button $w.goright -text "Move To" -command [list moveto $axis right]] 	\
		  [entry $w.right -justify right -width 8 -textvariable ${axis}_right]  \
		  [label $w.lul -text $movelab -anchor w]

	eval Grid [labentry "Sample Period"  $w.period -width 8]				\
		  [label $w.sul -text "* 442 usec" -anchor w]

	}] - -

    global column1
    buildcolumn $column1 $w $axis
}] \
[InFrame $w.f2 {
	global column2
	upvar  axis	axis

    buildcolumn $column2 $w $axis
}]

    catch { msg_waitgroup WAVESERV column }

    return $w
}

proc moveto { axis dir } {
	upvar ${axis}_$dir here

    if { ![string compare $here ""] } { return }

    msg_cmd WAVESERV "${axis}move $here" 90000
}

