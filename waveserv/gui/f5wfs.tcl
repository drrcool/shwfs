#!/data/mmti/bin/wish
#

if { ![string compare $env(HOST) packrat] } {
    set wavefront wavefront
} else {
    set wavefront 128.196.100.10
}

set env(WAVESERV) $wavefront:3000
set env(WAVEWFS)  $wavefront:3001
set env(WAVESCI)  $wavefront:3002
set env(WAVEPIX)  $wavefront:3003

proc home { } {
    msg_client WAVESERV
    msg_cmd    WAVESERV home 90000
}
proc stow { } {
    msg_client WAVESERV
    msg_cmd    WAVESERV stow 60000
}
proc select { camera } {
    msg_client WAVESERV
    msg_cmd    WAVESERV "select $camera" 60000
}
proc ref { } {
    msg_client WAVESERV
    msg_cmd    WAVESERV "pmove   1" 15000
    msg_cmd    WAVESERV "plite 1"
}
proc sky { } {
    msg_client WAVESERV
    msg_cmd    WAVESERV "pmove 620" 15000
    msg_cmd    WAVESERV "plite 0"
}

array set Map {
	toffset	toffset 
	foffset	foffset

	tinsoff toffxxx
	finsoff foffxxx

	wfscpos p70
	scicpos p71
	wfstins p72
	scitins p73
	wfsfins p74
	scifins p75
}
proc vset { name value } {
    msg_client WAVESERV
    msg_cmd    WAVESERV "set $::Map($name) $value" 10000
}

proc setbox { camera args } { 
    cam::init $camera WAVE[string toupper $camera]

    if { [llength $args] == 0 } {
	switch $camera {
	  wfs { set args "0  512 0  512 1" }
	  pix { set args "0 1280 0 1024 1" }
	  sci { set args "0 1034 0 1024 1" }
	}
    }
    if { [llength $args] == 4 } {
	foreach { x1 nx y1 ny } $args {}

	cam::setbox $camera $x1 $nx $y1 $ny $bin
    }

    error "setbox camera x1 nx y1 ny bin"
}
proc expose { camera seconds { file test.fits } { type light } } {
	upvar #0 $camera C

    set C(img) $file
    cam::setexp $camera $seconds $type
    cam::expose $camera frame

    while { [string compare $C(mode) idle] } {
	vwait ::${camera}(mode)
    }
}

proc f5wfs { command args } {
    eval $command $args
}

source ../try.tcl
source ../msg.tcl

#source ./camera.tcl

try {
    eval f5wfs $argv
} {
	puts {
f5wfs command interface:

	home		- home the wfs system.
	stow		- stow the wfs off axis.

	select camera	- select the wfs or sci camera.
	setbox camera x1 nx y1 ny bin
	expose camera seconds file [exptype]

	    in the above commands <camera> is wfs or sci.
	

	sky		- wfs views the sky.
	ref		- wfs views the reference light.

	vset toffset value	- set T axis offset
	vset foffset value	- set F axis offset

	vset tinsoff value	- set T axis instrument offset
	vset finsoff value	- set F axis instrument offset

	vset wfscpos value	- set wfs C axis position
	vset wfstins value	- set wfs T axis instrument offset
	vset wfsfins value	- set wfs F axis instrument offset

	vset scicpos value	- set sci C axis position
	vset scitins value	- set sci T axis instrument offset
	vset scifins value	- set sci F axis instrument offset
    }
}
