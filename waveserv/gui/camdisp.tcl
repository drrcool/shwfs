proc count { c } {
    incr ::${c}_cnt

    
    set file [open $::Counter w]

    set save {}
    foreach cam { wfs sci pix } {
      foreach val { dir pre cnt exp typ bin bx1 by1 bnx bny filters bins cooler shm } {
	lappend save "set ${cam}_$val [list [set ::${cam}_$val]]"
      }
      lappend save {}
    }
    puts $file "# Generic camera user interface config"
    puts $file "#"
    puts $file [join $save "\n"]
    
    close $file

    set datadir [clock format [clock seconds] -format "%Y.%m%d" -gmt 1]
    set filename "[set ::${c}_pre][format %04d [set ::${c}_cnt]]"


    if { [file exists $::DataDir/$filename.fits] } {
	set w    .camera
	set mess "The image file: $filename exists\nDo you really want to overwrite it?"

	set reply [tk_messageBox -parent $w -default no -icon warning -message $mess -type yesno]

        if { ![string compare $reply no] } {
	    return {}
        }
    }

    return $filename
}

proc checkonaxis { c } {
    set reply 1

catch {
    if { ![string compare $c wfs] && $::cA > -115       \
      || ![string compare $c pix] && $::cA > -115 	\
      || ![string compare $c sci] && $::cA <   15 } {
        set w .camera
	set mess "The $c Camera not on axis\nDo you really want an exposure?"

        if { ![string compare 									\
		[tk_messageBox -parent $w -default no -icon warning -message $mess -type yesno]	\
		no] } {
	    set reply 0
        }
    }
}

    return $reply
}
proc fits2ds9 { frame fits { load 0 } { key {} } { siz {} } } {
    switch $::env(USER) {
	wave    { set xpatarget wavefront-ds9 }
	john    { set xpatarget ds9 }
	default { set xpatarget mc9 }
    }

    if { [string compare $frame {}] } {
	    catch { exec xpaset -p $xpatarget frame $frame }
    }

    if { [string compare $key {}] } {
	if { $load } {
	    exec xpaset -p $xpatarget shm key $key $siz $fits
	} else {
	    exec xpaset -p $xpatarget update &
	}
    } else {
	catch { exec xpaset -p $xpatarget file $::DataDir/$fits.fits & }
    }
}

set pix_exp     35
set pix_gain    50
set pix_gainset  0

set w [Toplevel .camera "Wavefront Cameras" -585+0]
ToplevelRaise   .camera


proc drop { name var args } {
	eval tk_optionMenu $name $var [join $args]
	return $name
}

proc cooler { c onoff } { 
	set C [string toupper $c]

    msg_cmd WAVE$C "cooler $onoff"
}

proc setpoint { cam name indx op } {
	upvar $name setp

  catch {
    if { $setp == -50 } {
	.camera.${cam}.cool1 configure -background "green"
    } else {
	.camera.${cam}.cool1 configure -background "lightblue"
    }
  }
}

proc exptype { c } {
    if { ![string compare light [set ::${c}_typ]] } {
	set ::${c}_typ dark
    } else {
	set ::${c}_typ light
    }
}

proc camerabox { w Cam filter bin cool } {
	set c [string tolower $Cam]
	set w [frame $w.$c]

  Grid	[label  $w.camera -text "$Cam Camera" -background yellow] -	\
	[label  $w.state  -textvariable ${c}_state -width 13]		  -	\
	[button $w.expose -text Expose -command "expose $c frame" -state disabled] - 	\
	[button $w.abort  -text Abort  -command "abort  $c" -state disabled] -

	if { [llength $filter] } {
	    set filtel [label $w.lfilel -text "Flt" -justify right -anchor e]
	    set filter [drop  $w.filter ${c}_filter $filter]
	} else {
	    set filtel [label $w.filtel]
	    set filter [label $w.filter]
	}

  Grid 									 \
	[entry $w.exp -textvariable ${c}_exp -width 5 -justify right]	 \
	[label $w.sec -text [set ::${c}_expunits] -anchor w] 		 \
    	[label $w.lbin -text "Bin" -justify right -anchor e]		 \
	[drop  $w.bin  ${c}_bin $bin] 					 \
	[button $w.exptype -textvariable ${c}_typ -command "exptype $c"] \
        $filtel $filter



  Grid									\
	[label $w.x1l  -text X1  -justify right -anchor e]		\
	[entry $w.x1   -textvariable ${c}_x1 -width 5 -justify right]	\
	[label $w.y1l  -text Y1  -justify right -anchor e]		\
	[entry $w.y1   -textvariable ${c}_y1 -width 5 -justify right]	\
	[button $w.box -text Box -command "box $c"] 	 		\
	[label $w.prel -text pre:  -justify right -anchor e]		\
	[entry  $w.pre -width 8 -textvariable ${c}_pre -justify right] - \

  Grid									\
	[label $w.wdl  -text Nx -justify right -anchor e]		\
	[entry $w.wd   -textvariable ${c}_nx -width 5 -justify right]	\
	[label $w.htl  -text Ny -justify right -anchor e]		\
	[entry $w.ht   -textvariable ${c}_ny -width 5 -justify right]	\
	x						 		\
	[label $w.cntl  -text cnt:  -justify right -anchor e]		\
	[entry  $w.cnt   -width 5 -textvariable ${c}_cnt -justify right]

  if { $cool } {
    Grid								\
	[label  $w.temp  -textvariable ${c}_temp -width 6]		\
	[label  $w.deg   -text deg]					\
	[button $w.cool1 -text "On"  -command "cooler $c 1"] 		\
	[button $w.cool0 -text "Off" -command "cooler $c 0"] 		\
	[button $w.live  -text Live  -command "expose $c video" -state disabled]	\
	[button $w.cube  -text Cube  -command "expose $c ecube"]	\
	[entry  $w.ccnt  -textvariable ${c}_ccnt -width 5]
  } else {
    Grid								\
	[label  $w.lgain -text Gain]					\
	[entry  $w.gain -textvariable ${c}_gain -width 5 -justify right]	\
	x x								\
	[button $w.live  -text Live  -command "expose $c video"]	\
	[button $w.cube  -text Cube  -command "expose $c ecube"]	\
	[entry  $w.ccnt  -textvariable ${c}_ccnt -width 5]
  }

  Grid	x x								\
	[label $w.limage  -text Image: -justify right -anchor e] -	\
	[label $w.image  -textvariable ${c}_img -justify right -anchor e] - - -

  Grid $w
}


camerabox .camera Sci $sci_filters $sci_bins $sci_cooler
camerabox .camera WFS $wfs_filters $wfs_bins $wfs_cooler
camerabox .camera Pix $pix_filters $pix_bins $pix_cooler

proc filter  { c name indx op } {
	upvar $name value

    set C [string toupper $c]

    if { [string compare [set ::${c}_state] Idle] } {
	tk_messageBox -message "Cannot switch filters during exposure"	\
		-parent .camera						\
		-title "Filter warning" -type ok
        set value $::Filter
	return
    }
    msg_cmd WAVE$C "filter $value" 10000
}

proc box { c } {
    if { [set ::${c}_full] } {
	set ::${c}_full 0

	set ::${c}_x1 [set ::${c}_bx1]
	set ::${c}_y1 [set ::${c}_by1]
	set ::${c}_nx [set ::${c}_bnx]
	set ::${c}_ny [set ::${c}_bny]
    } else {
	set ::${c}_full 1

	set ::${c}_x1 [set ::${c}_fx1]
	set ::${c}_y1 [set ::${c}_fy1]
	set ::${c}_nx [set ::${c}_fnx]
	set ::${c}_ny [set ::${c}_fny]
    }
}

proc full { c name indx op } {
	upvar $name full

    if { $full } {
	.camera.$c.box configure -text Full
    } else {
	.camera.$c.box configure -text  Box
    }
}

proc timer { c name indx op } {
	upvar #0 ${c}_state state

    if { ![string compare -length 8 $state Exposing] } {
	upvar #0 ${c}_timer cnt
	set state "[lindex $state 0] [format %4d $cnt]"
    }
}

foreach n {   1   3   2 }		\
	C { WFS PIX SCI }		\
	c { wfs pix sci } {

   #if { [string compare $C PIX] } { continue }

    set env(WAVE$C) wavefront:300$n
    msg_client WAVE$C

    trace variable ${c}_state   w "state  $c"
    trace variable ${c}_full    w "full   $c"
    trace variable ${c}_filter  w "filter $c"

    set ::${c}_pre	   ${c}
    set ::${c}_cnt	      0
    set ::${c}_exp	      1
    set ::${c}_typ	  light

    set ::${c}_mode	  idle

    set ::${c}_siz [expr [set ::${c}_fnx] * [set ::${c}_fny] * 2 + 100000]

    set ::${c}_sid [shm::new [set ::${c}_shm] [set ::${c}_siz] 0666]
    set ::${c}_att [shm::att [set ::${c}_sid]]
    set ::${c}_chn [memchan -static [set ::${c}_att] [set ::${c}_siz]]
    fconfigure [set ::${c}_chn] -translation binary

    msg_subscribe WAVE$C state ${c}_state {}            0.001 10000
    msg_subscribe WAVE$C timer ${c}_timer "timer    $c" 0.001
    msg_subscribe WAVE$C temp  ${c}_temp
    msg_subscribe WAVE$C setp  ${c}_setp  "setpoint $c"

    box $c
 }

catch { source $Counter }

#msg_subscribe WAVEPIX gain  gain


