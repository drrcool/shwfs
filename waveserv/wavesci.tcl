

package provide camserv	1.0

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

	set statc [$S(driver)::stat $state]

    if { ![string compare $statc $statx] } {
	set state $statx
	set timer 0
	update
	return
    }

    if { $counter } {
	set counter [expr $counter -  100]
	set timer   [expr $counter / 1000]
    }
    update
	puts "state is $state, waiting for $statx"
    set wait [after 100 "camserv::wait $server $statx"]
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


 proc Update { server  } {
	upvar #0 $server S

    if { [catch {
	set ::temp [::$S(driver)::temp]
	#set ::setp [::$S(driver)::setp]
    } reply] } {
	puts $reply
    }

    after 5000 camserv::Update $server
 }

 proc server { server port driver allow } {
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

  msg_srvproc $server bin { xbin ybin }   {
	upvar s s; upvar #0 $s S
    ::$S(driver)::bin $xbin $ybin
  }
  msg_srvproc $server box { x1 y1 nx ny } {
	upvar s s; upvar #0 $s S
    ::$S(driver)::box $x1 $y1 $nx $ny
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
    catch { after cancel [set ::$S(camera)_wait }

    set ::$S(camera)_state Idle
    set ::$S(camera)_timer    0
  }
  msg_srvproc $server expose { exptype exptime } {
	upvar s s; upvar #0 $s S

    ::$S(driver)::expose $exptype $exptime
    set ::$S(camera)_counter [expr $exptime * 1000]
    set ::$S(camera)_state   Exposing
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

  proc ::$server.fits { s sock msgid cmd nbytes } {
	upvar #0 $s S
    ::$S(driver)::write $S(camera)
    camserv::sendfile $S(camera) $sock $msgid 0    $nbytes
  }

  proc ::$server.data { s sock msgid cmd nbytes } {
	upvar #0 $s S
    ::$S(driver)::write $S(camera)
    camserv::sendfile $S(camera) $sock $msgid 2880 $nbytes
  }

  proc ::$server.info { s sock msgid cmd } {
    set MsgCards 2

    msg_rpy $sock $msgid blk [expr 80 * $MsgCards]

    puts -nonewline $sock [camserv::fitscard CAMERA %32s MMTIWAVE]
    puts -nonewline $sock [binary format {A80} END]
    flush $sock
  }
  proc ::$server.exit { s sock msgid cmd } { exit }

  ${driver}::init
  msg_up $server
  Update $server
 }
}
