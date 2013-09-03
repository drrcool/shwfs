
package provide camclient 1.0

proc copyfits { filename server sock msgid ack size } {
        set fits [open $::DataDir/$filename.fits w+]
	fconfigure  $fits -translation binary 
	fconfigure  $sock -translation binary
        fcopy $sock $fits -size $size
	fconfigure  $sock -translation auto 
        close $fits

	return 1
}

proc copymemc { c server sock msgid ack size } {
	fconfigure  $sock -translation binary
        bob::read [set ::${c}_att] 0 $size $sock
	fconfigure  $sock -translation auto 

	return 1
}

proc abort  { c } {
	upvar #0 ${c}_state state
	upvar #0 ${c}_mode  mode

    set C [string toupper $c]

    switch $mode {
      icube -
      ecube {
	close [set ::${c}_file]
	if {  [set ::${c}_cube] != [set ::${c}_ccnt] } {
	    fits2ds9 {} [set ::${c}_img] 1
	}
	set ::${c}_ccnt ::${c}_cube
      }
    }

    if { [string compare $mode video] } {
        msg_cmd WAVE$C abort 10000
    }
    set mode abort
}

proc expose { c type } {
	upvar #0 ${c}_state state
	upvar #0 ${c}_exp   expose
	upvar #0 ${c}_typ   exptype
	upvar #0 ${c}_img   image
	upvar #0 ${c}_mode  mode

	upvar #0 ${c}_bin   bin
	upvar #0 ${c}_x1    x1
	upvar #0 ${c}_y1    y1
	upvar #0 ${c}_nx    nx
	upvar #0 ${c}_ny    ny

    if { [string compare $mode  idle] && [string compare $mode  abort] } { return }
    if { [string compare $state Idle] } { return }
    #if { ![checkonaxis $c]    	      } { return }

    set C [string toupper $c]


    switch $type { 
      frame {
	if { ![string compare [set image [count $c]] {}] }  { return }
      }
      video {
	set ::${c}_shmload 1
      }
      ecube -
      icube {
	if { ![string compare [set image [count $c]] {}] }  { return }

	set ::${c}_shmload 1
	set ::${c}_cube [set ::${c}_ccnt]
        set ::${C}_file [open $::DataDir/$image.fits w+]
      }
    }

    if { ![string compare $c pix] 
      && $::pix_gain != $::pix_gainset } {
        msg_cmd WAVEPIX "param gain $::pix_gain" 20000
	set ::pix_gainset $::pix_gain
    }
    msg_cmd WAVE$C "setbox 0 $x1 $nx $bin $y1 $ny $bin" 10000
    msg_cmd WAVE$C "expose 0 $exptype $expose" 		10000

    set mode $type
}


proc reexpose { c n exptype expose } {
	upvar #0 ${c}_mode mode
	set C [string toupper $c]

    msg_cmd  WAVE$C "fits 0 $::MaxData" 20000 sync no "copymemc ${c}"
    fits2ds9 {} "${c}_live" [set ::${c}_shmload] [set ::${c}_shm] [set ::${c}_siz]
    set ::${c}_shmload 0


    switch $mode {
      abort { msg_cmd WAVE$C abort 10000;  return }
      frame { return }
      icube -
      ecube {
	incr ::${c}_ccnt -1
	if { ![set ::${c}_ccnt] } {
	     
	}
      }
    }

    msg_cmd WAVE$C "expose 0 $exptype $expose" 10000
}

set  statx {}
proc state { c name indx op } {

	global DataDir MaxData
	upvar    $name     state
	upvar #0 ${c}_img  img
	upvar #0 ${c}_mode mode

	set C [string toupper $c]

  if { ![string compare $mode abort] } {
	msg_cmd WAVE$C abort
	set mode idle
  } elseif { [string compare $mode idle] } {

    if { ![string compare   $state Idle] } {
	set state Idle
	set mode  idle
    }

    if { ![string compare -length 8 $state Exposing] } {
	upvar #0 ${c}_timer cnt
	set state "[lindex $state 0] [format %4d $cnt]"
    }
    if { ![string compare $state Exposed] } {
	switch $mode {
	  video - 
	  frame {
	    if { [catch { msg_cmd WAVE$C readout }] } {
		msg_cmd WAVE$C abort
		set mode idle
	    }
	  }
	}
    }

    if { ![string compare $state Read] } {
	switch $mode {
	  icube -
	  ecube -
	  video {
	    upvar #0 ${c}_exp   expose
	    upvar #0 ${c}_typ   exptype

	    after 1 "reexpose $c 0 $exptype $expose"
	  }
	  frame {
            if { [catch { msg_cmd  WAVE$C "fits 0 $::MaxData" 20000 sync no "copyfits $img" }] } {
		msg_cmd WAVE$C abort
		set mode idle
	    }
	    msg_cmd WAVE$C idle

	    fits2ds9 1 $img
	  }
	}
    }
  }

    if { [string compare $state Idle] } {
	$::w.$c.expose configure -state disabled
	$::w.$c.live   configure -state disabled
	$::w.$c.abort  configure -state normal
    } else {
	$::w.$c.expose configure -state normal
	$::w.$c.live   configure -state normal
	$::w.$c.abort  configure -state disabled
    }

    set ::statx $state
}

