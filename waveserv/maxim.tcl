# Maxim DL tcl server procs
#
package require tcom
package provide maxim 1.0

array set Filters {
	U	0
	B	1
	V	2
	R	3
	I	4
}

set null {}


namespace eval maxim {
 global null
 set nul $null

 proc init { camera } {
	set ::state Init
	update

	variable bin	   1 
	variable x1	   0 
	variable y1	   0 
	variable nx	1034 
	variable ny	1024 

 	variable aut [::tcom::ref createobject "AutoItX.Control"]
	variable cam [::tcom::ref createobject "MaxIm.CCDCamera"]
	$cam -set AutoDownload False
	maxim::link
	#maxim::camera  1 10
	after 100
	maxim::setbox 0 1 1024 8 1 1024 8
	after 500
	maxim::expose fake 0
	while { [string compare [maxim::stat Exposing] Exposed] } {
	     after 1000 { set ::waitmaxim 1 }
	     vwait ::waitmaxim
	}
	maxim::read
	while { [string compare [maxim::stat Reading] Read] } {
	     after 1000 { set ::waitmaxim 1 }
	     vwait ::waitmaxim
	}
	after 100
	maxim::setbox 0 1 1024 1 1 1024 1

	set ::state  Idle
 }

 proc nx    { } { return 1034; }
 proc ny    { } { return 1024; }

 proc link { } {
	variable cam
	variable aut

	if { [$cam -get LinkEnabled] } {
	    return
	}

 	$cam -set LinkEnabled True
	$aut WinHide       "MaxIm" "Main CCD Camera"
 } 
 proc unlink { } {
	variable cam
	variable aut

 	$cam -set LinkEnabled False
	$aut WinHide       "MaxIm" "Main CCD Camera"
 } 

 proc temp { } {
	variable cam

	format %.1f [$cam -get Temperature]
 }

 proc WinActivate { aut win txt to } {
	$aut WinActivate   $win $txt
	$aut WinWaitActive $win $txt $to
	after 250
 }

 proc camera { camera filter } {
	variable cam
	variable aut
	variable nul

	maxim::link
	

	if { [$aut IfWinExist "Windows Task Manager" $nul] } {
	    $aut WinHide "Windows Task Manager" $nul
	}
	if { [$aut IfWinExist "Setup" $nul] } {
	    $aut WinHide "Setup" $nul
	    after 500
	}

	if { ![$aut IfWinExist "MaxIm CCD" $nul] } {
	    if { [$aut IfWinExist  "MaxIm DL" $nul] } {
		$aut WinActivate   "MaxIm DL" $nul
		$aut WinWaitActive "MaxIm DL" $nul
		$aut Send ^w
	        after 500
	    } else {
		error "MaxIm DL Main window missing?"
	    }
	}

	WinActivate $aut "MaxIm CCD"   $nul 5
	$aut LeftClick 320  40
	after 100
	$aut Send !d

	$aut Send !s
	WinActivate $aut "Setup"     $nul 5
	$aut LeftClick 132 118
	after 100
	$aut Send N
	after 100
	$aut Send "{DOWN $camera}"
	after 100
	$aut Send "{ENTER 2}"
	after 100

	WinActivate $aut "MaxIm CCD" $nul 5
	$aut LeftClick 220  75
	after 100
	WinActivate $aut "Setup"     $nul 5
	$aut LeftClick 422  70
	$aut Send N
	after 100
	if { $filter } {
	    $aut Send "{DOWN $filter}"
	    after 100
	}
	$aut Send "{ENTER 2}"
	after 100

	WinActivate $aut "MaxIm" "Main CCD Camera" 5
	$aut Send !c
	$aut WinHide     "MaxIm" "Main CCD Camera"

	after 1000

	if { [$aut IfWinExist "Error Initializing Camera" $nul] } {
		$aut Send "{ENTER 2}"
		error "maxim: error initializing camera"
	}
	if { [$aut IfWinExist "Error Initializing Filter Wheel" $nul] } {
		$aut Send "{ENTER 2}"
		error "maxim: error initializing filter wheel"
	}
 }

 proc xbin { } { variable cam; $cam -get BinX }
 proc ybin { } { variable cam; $cam -get BinY }
 proc x1   { } { variable cam; $cam -get StartX }
 proc y1   { } { variable cam; $cam -get StartY }

 proc W    { } { variable cam; $cam -get NumX }
 proc H    { } { variable cam; $cam -get NumY }
 proc B    { } { variable cam; return 16 }
 proc setp { } { variable cam; $cam -get TemperatureSetPoint }

 proc cooler { onoff } {
	variable cam

    $cam -set CoolerOn 1

    if { $onoff } {
	$cam -set TemperatureSetPoint -50.0
    } else {
	$cam -set TemperatureSetPoint  10.0
    }
 }

 proc filter { filter } {
	variable cam

	$cam -set filter [expr $::Filters($filter)+0]
	$cam expose 1 1 -1
	after 2000
	$cam abortexposure
 }

 proc stat { state } {
	variable cam

    if { ![string compare $state Idle] } { return Idle	}

    if { ![string compare $state Exposing]	\
       && [$cam -get ReadyForDownload] } { return Exposed }
    if { ![string compare $state Reading]	\
       && [$cam -get ImageReady] } 	 {
	maxim::write MAXIM
	return Read
    }

    return $state
 }

 proc write { image } { variable cam;  $cam SaveImage "$::DataDir\\$image.fit" }
 proc read  { }       { after 10 maxim::readout }
 proc readout { }     { variable cam;  $cam StartDownload }
 proc data { n } {
    set fits [open MAXIM.fit]
    fconfigure $fits -translation binary

    seek $fits 2880
    set data [::read $fits]
    close $fits

    return $data
 }
 proc info { n } {
	set list {}
	lappend list [camserv::fitscard BSCALE %.1f     1.0]
	lappend list [camserv::fitscard BZERO  %.1f 32768.0]

	return $list
 }

 proc expose { exptype exptime } {
	variable cam

	set shutter 0
        switch $exptype {
	    light { set shutter 1 }
	}

	$cam expose $exptime $shutter -1
 }

 proc setbox { n x1 xdata xbin y1 ydata ybin } {
	variable cam

    $cam -set BinX  1
    $cam -set BinY  1
    $cam -set NumX  1034
    $cam -set NumY  1024

    $cam -set StartX $x1
    $cam -set StartY $y1
    $cam -set NumX   [expr $xdata * $xbin]
    $cam -set NumY   [expr $ydata * $ybin]
    $cam -set BinX   $xbin
    $cam -set BinY   $ybin
 }

 proc getbox { n } {
	variable cam

    set x1    [$cam -get StartX]
    set y1    [$cam -get StartY]
    set xdata [$cam -get NumX]
    set ydata [$cam -get NumY]
    set xbin  [$cam -get BinX]
    set ybin  [$cam -get BinY]

    return  "xbin $xbin x1 $x1 xdata $xdata ybin $ybin y1 $y1 ydata $ydata"
 }

 proc params { args } {
	error "Maxim driver has no parameters"
 }
	
 proc setccd { config						 \
	xbin xpreskip xunderscan xskip xdata xpostskip xoverscan \
	ybin ypreskip yunderscan yskip ydata ypostskip yoverscan \
 } {
	variable cam

    if { $xpreskip != 0 || $ypreskip != 0 } {
	error "Cannot preskip with maxim control software"
    }
    if { $xunderscan != 0 || $yunderscan != 0 } {
	error "Cannot underscan with maxim control software"
    }
    set nx [expr $xpreskip+$xunderscan+$xskip+$xdata*$xbin+$xpostskip+$xoverscan]
    set ny [expr $ypreskip+$yunderscan+$yskip+$ydata*$ybin+$ypostskip+$yoverscan]

	set ::maxim::xbin $xbin
	set ::maxim::ybin $ybin
	set ::maxim::x1 $xskip
	set ::maxim::y1 $yskip
	set ::maxim::nx $nx
	set ::maxim::ny $ny

 }

 proc filters { } {
	variable cam
	$cam -get FilterNames
 }

 proc abort { } {
	variable cam
	$cam AbortExposure
 }

 proc status { } {
	variable cam

	variable AmbTemp [$cam -get AmbientTemperature]
	variable CCDTemp [$cam -get Temperature]
	variable Cooler  [$cam -get CoolerOn]
 }

 # A proc to handle the demo mode of Maxix/DL
 #
 proc popdowndemo { args } {
	# Get rid of the demo boxes
	#
	set quick [lindex $args 0]

	if { [string compare $quick quick] } {
	    variable aut

	    after 30000 
	    $aut WinWaitActive "About MaxIm DL" ""
	    $aut WinClose      "About MaxIm DL" ""
	    $aut WinWaitActive "MaxIm DL" "<<"
	    $aut WinClose      "MaxIm DL" "<<"
	}
 }
}
