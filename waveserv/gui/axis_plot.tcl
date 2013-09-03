# Axis Plotting Window
#

source "/data/mmti/src/mmtitcl/starbase.tcl"
source "/data/mmti/src/mmtitcl/filemenu.tcl"

proc nop { code } { }

set n 0
foreach axis { m t c f } {
    foreach type { A C } {
	global bit${axis}${type}
	set bit${axis}${type} [expr 1 << $n]

	incr n
    }
}
set bitmD	[expr 1 <<  8]
set bittD	[expr 1 <<  9]
set bitcD	[expr 1 << 10]
set bitfD	[expr 1 << 11]


proc axis_PW { } {
    if { [winfo exists .axis_plot] == 0 } {
	axis_plot [Toplevel .axis_plot "Axis Motion Plot" +100+100]
    }
    ToplevelRaise .axis_plot
}


proc axis_plot_print { filename } {
	global graph


	switch -glob -- $filename {
	    /* -
	    .* {
		$graph configure -title "Axis Motion Profile - $filename [clock format [clock seconds]]"
		$graph postscript output $filename
		$graph configure -title "Axis Motion Profile"
	    }
	    default {
		$graph postscript output ./plotout.ps
		exec lpr -P$filename < ./plotout.ps
	    }
	}
}

proc axis_plot { w } {
	global axis_data graph

    set filemenu [filemenu [Menubar  $w] NullFileClass]
    menu $w.menubar.optsmenu -tearoff 0

    $w.menubar add cascade -menu $w.menubar.optsmenu -label "Options"
    $w.menubar.optsmenu add command -label "Configure ..."		\
	-command { axis_plot_OP }

    setvalue $filemenu open  { axis_plot_open  }
    setvalue $filemenu save  { axis_plot_save  }
    setvalue $filemenu print { axis_plot_print }
    setvalue $filemenu types {
        { "Axis motion data"  .xyztp 		}
        { "All files"                     * 	}
    }

	set graph [graph $w.plot -title "Axis Motion Profile"	\
			-height 7.25i -width 11.25]

	$graph xaxis configure -title "Time in sec" 	\
			-tickfont {courier 14 bold}	\
			-titlefont {courier 14 bold}
	$graph yaxis configure -title "Position in mm" 	\
			-tickfont  {courier 14 bold}	\
			-titlefont {courier 14 bold}
	$graph y2    configure -title "DAC in volts" 	\
			-tickfont  {courier 14 bold}	\
			-titlefont {courier 14 bold}


	global period
	global timebase 

	catch { vector timebase(3000) }
	set leng [timebase length]

	for { set i 0 } { $i < $leng } { incr i } {
		set timebase($i) [expr $i * (0.000440 * $period)]
	}

	    foreach axis 	{ m     t   c     f     } \
		    color	{ blue  red green black } {

		global v${axis}A v${axis}C v${axis}E v${axis}D
		global c${axis}

		catch { vector v${axis}A(3000) }
		catch { vector v${axis}C(3000) }
		catch { vector v${axis}E(3000) }
		catch { vector v${axis}D(3000) }

		set v${axis}A(0:[expr $leng-1]) 0
		set v${axis}C(0:[expr $leng-1]) 0
		set v${axis}E(0:[expr $leng-1]) 0
		set v${axis}D(0:[expr $leng-1]) 0

		set c${axis} $color
	    }

	Blt_ZoomStack $graph
        bind $graph <ButtonPress-2>   	{ PikMarkers %W %x %y }
        bind $graph <ButtonRelease-2> 	{ DonMarkers %W %x %y }
        bind $graph <B2-Motion> 	{ MovMarkers %W %x %y }

	set coords [MakeXCoords 0]
	$graph marker create line -coords $coords -name "done"

	grid [button $w.acq -text "Acquire Data" -command "axis_gatdat"]		\
	     [label  $w.spacer1 -width 17]						\
	     [label  $w.done  -text "Map Done"]						\
	     [checkbutton $w.done1 -text "" -command "MapEndMove $graph"]	\
	     [checkbutton $w.mark -text "Map Markers" -command "MapMarkers $graph"]	\
	     [entry $w.length0 -textvariable length0 -justify right -width 10] 		\
	     [entry $w.length1 -textvariable length1 -justify right -width 10] 		\
	     [label  $w.spacer2 -width 10]						\
		-sticky news

	Grid $graph - - - - - - - -
}

set Markers(mapped)	0
set Markers(mark0,move) 0
set Markers(mark1,move) 0
set Markers(mark2,move) 0
set Markers(mark3,move) 0
set Markers(X)		0
set Markers(done)	0

proc UpdateLengths { } {
	global length0
	global length1
	global Markers

	set length0 [format "%7.3f" [expr abs($Markers(mark0,X) - $Markers(mark1,X))]]
	set length1 [format "%7.3f" [expr abs($Markers(mark2,Y) - $Markers(mark3,Y))]]
}

proc DonMarkers { graph x y } {
		global Markers
	
	set Markers(mark0,move) 0
	set Markers(mark1,move) 0
}

proc PikMarkers { graph x y } {
		global Markers

    if { $Markers(mapped) == 1 } {
	GetGraphCoords $graph $x $y X Y
	set Markers(X) $X
	set Markers(Y) $Y

	GetWindoCoords $graph $Markers(mark0,X) 0 X Y
	if { abs($X-$x) < 20  } { set Markers(mark0,move) 1
	} else			{ set Markers(mark0,move) 0 }

	GetWindoCoords $graph $Markers(mark1,X) 0 X Y
	if { abs($X-$x) < 20  } { set Markers(mark1,move) 1 
	} else			{ set Markers(mark1,move) 0 }

	GetWindoCoords $graph 0 $Markers(mark2,Y) X Y
	if { abs($Y-$y) < 20  } { set Markers(mark2,move) 1 
	} else			{ set Markers(mark2,move) 0 }

	GetWindoCoords $graph 0 $Markers(mark3,Y) X Y
	if { abs($Y-$y) < 20  } { set Markers(mark3,move) 1 
	} else			{ set Markers(mark3,move) 0 }
    }
}

proc MovMarkers { graph x y } {
		global Markers

	GetGraphCoords $graph $x $y X Y

	if { $Markers(mark0,move) } {
	    set Markers(mark0,X) [expr $Markers(mark0,X) + ($X-$Markers(X))]
	    set coords [MakeXCoords $Markers(mark0,X)]
	    $graph marker create line -coords $coords -name "mark0"
	}
	if { $Markers(mark1,move) } {
	    set Markers(mark1,X) [expr $Markers(mark1,X) + ($X-$Markers(X))]
	    set coords [MakeXCoords $Markers(mark1,X)]
	    $graph marker create line -coords $coords -name "mark1"
	}
	if { $Markers(mark2,move) } {
	    set Markers(mark2,Y) [expr $Markers(mark2,Y) + ($Y-$Markers(Y))]
	    set coords [MakeYCoords $Markers(mark2,Y)]
	    $graph marker create line -coords $coords -name "mark2"
	}
	if { $Markers(mark3,move) } {
	    set Markers(mark3,Y) [expr $Markers(mark3,Y) + ($Y-$Markers(Y))]
	    set coords [MakeYCoords $Markers(mark3,Y)]
	    $graph marker create line -coords $coords -name "mark3"
	}

	set Markers(X) $X
	set Markers(Y) $Y
	UpdateLengths
}


proc MapEndMove { graph } {
		global Markers

	if { $Markers(done) == 1 } {
	    $graph marker delete done
	    set Markers(done) 0
	} else {
	    set Markers(done) 1
	    set coords [MakeXCoords [msg_cmd WAVESERV "pmac 0 m95"]]
	    $graph marker create line -coords $coords -name "done"
	}
}

proc MapMarkers { graph } {
		global Markers

	if { $Markers(mapped) == 1 } {
	    $graph marker delete mark0
	    $graph marker delete mark1
	    $graph marker delete mark2
	    $graph marker delete mark3

	    set Markers(mapped) 0
	} else {
	    GetLimits $graph xaxis X0 X1
	    GetLimits $graph yaxis Y0 Y1

	    set Markers(mark0,X) [expr $X0 + ($X1-$X0)*.10]
	    set coords [MakeXCoords $Markers(mark0,X)]
	    $graph marker create line -coords $coords -name "mark0"

	    set Markers(mark1,X) [expr $X1 - ($X1-$X0)*.10]
	    set coords [MakeXCoords $Markers(mark1,X)]
	    $graph marker create line -coords $coords -name "mark1"

	    set Markers(mark2,Y) [expr $Y0 + ($Y1-$Y0)*.10]
	    set coords [MakeYCoords $Markers(mark2,Y)]
	    $graph marker create line -coords $coords -name "mark2"

	    set Markers(mark3,Y) [expr $Y1 - ($Y1-$Y0)*.10]
	    set coords [MakeYCoords $Markers(mark3,Y)]
	    $graph marker create line -coords $coords -name "mark3"

	    set Markers(mapped) 1
	}
	UpdateLengths
}

proc MakeYCoords { y } {
	return "-Inf $y Inf $y"
}
proc MakeXCoords { x } {
	return "$x Inf $x -Inf"
}

proc GetWindoCoords { graph x y xret yret } {
	upvar $xret X
	upvar $yret Y
 
    set coords [$graph transform $x $y]
    set X [lindex $coords 0]
    set Y [lindex $coords 1]
}

proc GetGraphCoords { graph x y xret yret } {
	upvar $xret X
	upvar $yret Y
 
    set coords [$graph invtransform $x $y]
    set X [lindex $coords 0]
    set Y [lindex $coords 1]
}

proc GetLimits { graph axis xret yret } {
	upvar $xret X
	upvar $yret Y

    set coords [$graph $axis limits]
    set X [lindex $coords 0]
    set Y [lindex $coords 1]
}

proc BltMarker  { graph x y } {
	puts "$graph $x $y"
}


proc listbits { axis } {
	set i20 [msg_cmd WAVESERV "pmac 0 i20"]

	set i20 "0x[string range $i20 2 [expr [string length $i20] - 2]]"

	set ACQ {}
	foreach vec { mA     mC     tA     tC     cA     cC	fA     fC   
		      mD     tD     cD     fD } {
		upvar #0 bit$vec bit

		if { [expr $i20 & $bit] } {
		     set ACQ "$ACQ $vec"
		}
	}

	return $ACQ
}

proc axis_gatdat { } {
	global Serving
	global timebase
	global graph
	global Markers

	set pmac 0

	  msg_cmd WAVESERV "pmac $pmac p94=1"
          if { [msg_cmd WAVESERV "pmac $pmac p94"] == 1 } {

	    set period 	[msg_cmd WAVESERV "pmac   $pmac i19"]
	    set data   	[join [msg_cmd WAVESERV "gatdat $pmac" 30000]]
	    set ACQ 	[listbits $pmac]

	    set n 	[expr int([llength $data] / [llength $ACQ])]
	    timebase length $n
	    
	    for { set i 0 } { $i < $n } { incr i } {
		    set timebase($i) [expr $i * (0.000440 * $period)]
	    }

	    set command ""
	    set print ""
	    foreach vec $ACQ {
		global v${vec}
		set command [concat $command "set v${vec}(\$i) \$$vec;"]
		set print [concat $print "\$$vec;"]
	    }

	    set i 0
	    foreach $ACQ $data {
		if { $i >= $n } { break }

		eval $command
		incr i
	    }

	    foreach axis { m t c f } {
		v${axis}E set [v${axis}C - v${axis}A]
	    }
	  }

	  if { $Markers(done) } {
	      set coords [MakeXCoords [msg_cmd WAVESERV "pmac $pmac m95"]]
	      $graph marker create line -coords $coords -name "done$pmac"
	  }

	  msg_cmd WAVESERV "pmac $pmac p94=0"
}

proc axis_plot_OP { } {
    if { [winfo exists .axis_plot_options] == 0 } {
	axis_plot_options [Toplevel .axis_plot_options "Axis Motion Plot Options" +0+0]
    }
    ToplevelRaise .axis_plot_options
}

proc axis_plot_options { w } {

    set pmac 0

	foreach axis { m t c f } {
		global v${axis}Amapped
		global v${axis}Cmapped
		global v${axis}Dmapped
		global v${axis}Emapped

	    Grid [label      $w.w${axis} -text $axis]		\
		[checkbutton $w.v${axis}Amapped 			\
			-command "vmapp $w $axis A"]		\
		[label 	     $w.w${axis}actual_l -text "Actual "]\
		[checkbutton $w.v${axis}Cmapped 			\
			-command "vmapp $w $axis C"]		\
		[label       $w.w${axis}commanded_l -text "Commanded"]	\
		[checkbutton $w.v${axis}Dmapped 			\
			-command "vmapp $w $axis D"]		\
		[label       $w.w${axis}dac_l -text "DAC"]	\
		[checkbutton $w.v${axis}Emapped 			\
			-command "vmapp $w $axis E"]		\
		[label       $w.w${axis}error_l -text "Error"]	\
	}
}

proc vmapp { w axis type } {
	    global graph
	    upvar #0 v${axis}${type}mapped mapped
	    upvar #0 c${axis} color

    switch $type {
	A { set dash { }	}
	C { set dash { 2 2  }	}
	D { set dash { 1 2 3 }	}
	E { set dash { 3 3 }	}
    }

    if { $mapped == 1 } {
      if { ![string compare $type D] } {
	  set axisside y2
      } else {
	  set axisside y
      }
      $graph element create v${axis}${type} -xdata timebase -ydata v${axis}${type} \
		-color $color -symbol none -dashes $dash -mapy $axisside
    } else {
	$graph element delete v${axis}${type}
    }
}
