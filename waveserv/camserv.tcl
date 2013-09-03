
package provide camserv	1.0

 proc clip { v min max } {
	if { $v < $min } { return $min }
	if { $v > $max } { return $max }

	return $v
 }

namespace eval camserv {
 proc fitscard { name type value { comment {} } } {
   binary format {A8A2A32A3A35} $name "= " [format $type $value] " / " $comment
 }


 proc wait { server statx } {
	upvar #0 $server S
	upvar #0 $S(camera)_state   state
	upvar #0 $S(camera)_timer   timer
	upvar #0 $S(camera)_counter counter
	upvar #0 $S(camera)_wait    wait
	upvar #0 $S(camera)_mode    mode
	upvar #0 $S(camera)_sock    sock
	upvar #0 $S(camera)_msgid   msgid

	set statc [$S(driver)::stat $state]

    if { ![string compare $statc $statx] } {

	switch $mode {
	  full -
	  box  { 
	    switch $state {
	      Exposed { $S(driver)::read     }
	      Read    { msg_ack $sock $msgid }
	    }
	  }
	  cube { }
	}
	set state $statx
	set timer 0
	update
	return
    }

    if { $counter } {
	set counter [expr $counter -  100]
	set timer   [expr $counter / 1000]
    }
    set wait [after 50 "camserv::wait $server $statx"]
 }

 proc sendfile { file sock msgid offset nbytes } {
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

 proc senddata { driver sock msgid header n nbytes } {
    fconfigure $sock -translation binary

    if { $header } { 
	set hsiz 2880
    } else {
	set hsiz    0
    }

    set data [::${driver}::data $n]
    set dsiz [string length $data]
    set dpad [expr (2880-$dsiz%2880)%2880]
    set size [expr $dsiz + $dpad + $hsiz]

    if { $nbytes == 0 || $size < $nbytes } {
	set nbytes $size
    }
    msg_rpy $sock $msgid blk $nbytes
    flush $sock

    if { $header } { 
	    set cards 0
	    incr cards; puts -nonewline $sock [camserv::fitscard SIMPLE %s T]
	    incr cards; puts -nonewline $sock [camserv::fitscard BITPIX %d [::${driver}::B]]
	    incr cards; puts -nonewline $sock [camserv::fitscard NAXIS  %d 2]
	    incr cards; puts -nonewline $sock [camserv::fitscard NAXIS1 %d [::${driver}::W]]
	    incr cards; puts -nonewline $sock [camserv::fitscard NAXIS2 %d [::${driver}::H]]

	    set xbin [::${driver}::xbin]
	    set ybin [::${driver}::ybin]

	    set ltm1_1 [expr 1.0/$xbin]
	    set ltm2_2 [expr 1.0/$ybin]

	    incr cards; puts -nonewline $sock [camserv::fitscard LTM1_1 %f $ltm1_1]
	    incr cards; puts -nonewline $sock [camserv::fitscard LTM2_2 %f $ltm2_2]

	    set xsum   [expr ($xbin-1)/2.0 * $ltm1_1]
	    set ysum   [expr ($ybin-1)/2.0 * $ltm2_2]

	    set ltv1   [expr -1 * [::${driver}::x1] * $ltm1_1 + $xsum]
	    set ltv2   [expr -1 * [::${driver}::y1] * $ltm2_2 + $ysum]

	    incr cards; puts -nonewline $sock [camserv::fitscard LTV1 %f $ltv1]
	    incr cards; puts -nonewline $sock [camserv::fitscard LTV2 %f $ltv2]
	    incr cards; puts -nonewline $sock [camserv::fitscard BSCALE %d 1]
	    incr cards; puts -nonewline $sock [camserv::fitscard BZERO %d 32768]

	    set info [::${driver}::info $n]
	    foreach card $info { puts  -nonewline $sock $card }
	    incr cards [llength $info]

	    incr cards; puts -nonewline $sock [binary format A80 END]

	    set padd [expr (2880-[expr $cards * 80]%2880)%2880]
	    puts -nonewline $sock [binary format A$padd {}]
    }

    puts -nonewline $sock $data
    puts -nonewline $sock [binary format A$dpad {}]

    flush $sock
    fconfigure $sock -translation auto
 }

 proc Update { server  } {
	upvar #0 $server S

    if { [catch {
	set ::$S(camera)_temp [::$S(driver)::temp]
	set ::$S(camera)_setp [::$S(driver)::setp]
    } reply] } {
	puts $reply
    }

    after 5000 camserv::Update $server
 }

 proc server { server port driver cameraid allow } {
	upvar #0 $server S

  set ::env($server) localhost:$port
  set camera [string tolower $server]

  set S(camera)	$camera
  set S(driver)	$driver

  set ::${camera}_state    Idle

  msg_server   $server

  msg_publish  $server state	${camera}_state 
  msg_publish  $server timer	${camera}_timer 
  msg_publish  $server temp 	${camera}_temp
  msg_publish  $server setp 	${camera}_setp

  msg_register $server info
  msg_register $server fits
  msg_register $server data
  msg_register $server exit
 
  msg_allow $server $allow

  msg_srvproc $server setbox { n { x1 {} } { xdata {} } { xbin {} }	\
				 { y1 {} } { ydata {} } { ybin {} } } {
	upvar s s; upvar #0 $s S

    if { ![string compare $n $S(config,C)] \
      && ![string compare $x1 {}] } {
        return [::$S(driver)::getbox $n]
    }
	
    set maxx [::$S(driver)::nx]
    set maxy [::$S(driver)::ny]

    set x1 [clip $x1 0 $maxx]
    set y1 [clip $y1 0 $maxy]
    set x2 [clip [expr $x1 + $xdata*$xbin] 1 $maxx]
    set y2 [clip [expr $y1 + $ydata*$ybin] 1 $maxy]

    set xdata [expr ($x2 - $x1)/ $xbin]
    set ydata [expr ($y2 - $y1)/ $ybin]

    set S(config,$n,x1) $x1
    set S(config,$n,y1) $y1
    set S(config,$n,nx) $xdata
    set S(config,$n,ny) $ydata
    set S(config,$n,bx) $xbin
    set S(config,$n,by) $ybin

    set S(config,C) $n
    ::$S(driver)::setbox $n $S(config,$n,x1) $S(config,$n,nx) $S(config,$n,bx) \
	                    $S(config,$n,y1) $S(config,$n,ny) $S(config,$n,by) 

    return [::$S(driver)::getbox $n]
  }
  msg_srvproc $server getbox { n } {
    return ::$S(driver)::getbox $n
  }

  msg_srvproc $server filter { filter }   {
	upvar s s; upvar #0 $s S
    ::$S(driver)::filter $filter
  }
  msg_srvproc $server link   { }	  {
	upvar s s; upvar #0 $s S
    ::$S(driver)::link
  }
  msg_srvproc $server unlink { }	  {
	upvar s s; upvar #0 $s S
    ::$S(driver)::unlink
   }
  msg_srvproc $server cooler { onoff }	  {
	upvar s s; upvar #0 $s S

    ::$S(driver)::cooler $onoff
  }

  msg_srvproc $server param { name value } {
	upvar s s; upvar #0 $s S
	
    ::$S(driver)::param $name $value
  }

  msg_srvproc $server setccd {                  	 		 \
	colbin xpreskip xunderscan xskip xdata xpostskip xoverscan dwell \
	rowbin ypreskip yunderscan yskip ydata ypostskip yoverscan split \
	nrvshift preflash						 \
  } {
	upvar s s; upvar #0 $s S
    ::$S(driver)::setccd						     \
    $colbin $xpreskip $xunderscan $xskip $xdata $xpostskip $xoverscan $dwell \
    $rowbin $ypreskip $yunderscan $yskip $ydata $ypostskip $yoverscan $split \
    $nrvshift $preflash	
  }
  msg_srvproc $server abort  { } {
	upvar s s; upvar #0 $s S

    ::$S(driver)::abort
    catch { after cancel [set ::$S(camera)_wait] }

    set ::$S(camera)_state Idle
    set ::$S(camera)_timer    0
  }

  msg_register $server expose
  proc ::$server.expose { s sock msgid cmd n exptype exptime } {
	upvar #0 $s S

#    if { [string compare [set ::$S(camera)_state] Idle] } {
#	msg_nak $sock $msgid "Camera not Idle"
#    }
    ::$S(driver)::expose $exptype $exptime

    set ::$S(camera)_counter [expr $exptime * 1000]
    set ::$S(camera)_state   Exposing
    set ::$S(camera)_mode    $exptype
    set ::$S(camera)_sock    $sock
    set ::$S(camera)_msgid   $msgid

    switch $exptype {
      full -
      box  { }
      cube {
	# Set up cube 
      }
      default { msg_ack $sock $msgid }
    }
    camserv::wait $s Exposed
  }

  msg_srvproc $server idle { } {
	upvar s s; upvar #0 $s S
    catch { after cancel [set ::$S(camera)_wait] }
    set ::$S(camera)_state Idle
  }
  msg_srvproc $server readout { } {
	upvar s s; upvar #0 $s S
    set ::$S(camera)_state Reading
    update

    set ::$S(camera)_counter [expr 40 * 1000]
    ::$S(driver)::read
    camserv::wait $s Read
  }

  proc ::$server.fits { s sock msgid cmd n nbytes } {
	upvar #0 $s S

    camserv::senddata $S(driver) $sock $msgid 1 $n $nbytes
  }


  proc ::$server.data { s sock msgid cmd n nbytes } {
	upvar #0 $s S
    camserv::senddata $S(driver) $sock $msgid 0 $n $nbytes
  }

  proc ::$server.info { s sock msgid cmd } {
    set MsgCards 2

    msg_rpy $sock $msgid blk [expr 80 * $MsgCards]

    puts -nonewline $sock [camserv::fitscard CAMERA %32s MMTIWAVE]
    puts -nonewline $sock [binary format {A80} END]
    flush $sock
  }
  proc ::$server.exit { s sock msgid cmd } { exit }

  set ::${server}(config,C) {}
  ${driver}::init $cameraid
  msg_up $server
  Update $server
 }
}
