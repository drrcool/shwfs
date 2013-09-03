
set geometry +160+60

# Stow position is 36 degrees West of North when rotator is at 0
#
set instangle 38

package require msg		1.0

# Hacksaw is the TELESCOPE server but the hosts file on XP doesn't 
# appear to work.
#
set env(TELESCOPE) 128.196.100.19:5403
msg_client TELESCOPE


lappend auto_path .

source gui.tcl


package require pmac 		1.0
package require pmacserv	1.0
package require puntino		1.0
package require viahm		1.0
package require ljack		1.0

proc FastUpdate {} {
	if { [catch { pmacserv::stat 0 { m t c f } } reply] } {
		global errorInfo
		puts "pmac: $reply"
		puts $errorInfo
	}
	after 333  FastUpdate
}
proc SlowUpdate {} {
	global cpuTemp;		set cpuTemp [viahm::Tsens1]
	ReadTemps

	after 5000 SlowUpdate
}

set env(WAVE) localhost:3000

msg_server WAVE
msg_allow WAVE "*"

#msg_allow  WAVE {
#	192.168.1.2 192.168.1.1 hacksaw
#	192.168.1.31 128.196.100.19	hoseclamp hoseclamp.mmto.arizona.edu
#	128.196.100.28	  alewife.mmto.arizona.edu
#	128.196.100.31	  hacksaw.mmto.arizona.edu
#       128.196.100.19    hoseclamp.mmto.arizona.edu
#    localhost 192.168.1.209 192.168.1.231
#}

set pmac  [pmacserv::init WAVE 0 { m t c f } { 1 2 3 4 }]
set punt  [puntino::init COM1]
set viahm [viahm::init]
set ljack [ljack::init 0]
set ljack  0

set Temps {
	mMTemp	000	 100	-273
	hskT1	010	 100	-273
	pwbTemp 020	 100	-273
	plusV12 030	   1	   0
	minuV12 040	   1	   0
	plusV05 050	   1	   0
	vTemp   060	2000   	   0
	vLimit  070	2000	   0

	tMTemp	001	 100	-273
	hskT1	011	 100	-273

	cMTemp	002	 100	-273
	hskT1	012	 100	-273

	fMTemp	003	 100	-273
	hskT1	013	 100	-273

	mSTemp	004	 100	-273
	hskV1	014	   1	   0

	tSTemp	005	 100	-273
	hskV2	015	   1	   0

	cSTemp	006	 100	-273
	hskV3	016	   1	   0

	fSTemp	007	 100	-273
	ampTemp	017	 100	-273
}

global Mux
proc setmux { mux } {
    	global Mux

    if { ($Mux & 1) != ($mux & 1) } { ljack::setbit 0 [expr 0+16] [expr !!($mux & 1)] }
    if { ($Mux & 2) != ($mux & 2) } { ljack::setbit 0 [expr 1+16] [expr !!($mux & 2)] }
    if { ($Mux & 4) != ($mux & 4) } { ljack::setbit 0 [expr 2+16] [expr !!($mux & 4)] }

    set Mux $mux
}
proc ReadTemps { } {
	global Temps

    foreach { name position gain offset } $Temps {
	setmux [expr ($position/8)]
	global $name

	set    $name [format %.1f			\
			[expr [ljack::getvolt 0 [expr $position%8] 0]	\
				 * $gain + $offset]]

    }
}

# Add some WFS custom commands to the PMAC controlled axes.
#
proc brak { onoff } {
    if { $onoff == 1 } { 
	pmac::comm 0 "m1=0" 
	pmac::comm 0 "m2=0" 
	pmac::comm 0 "m3=0" 
	pmac::comm 0 "m4=0" 
	pmac::comm 0 "m6=0" 
	pmac::comm 0 "m7=1" 
    } else {
	pmac::comm 0 "m7=0"
    }
}
msg_srvproc WAVE spower { x } { pmac::comm 0 "m6=$x"; global spower; set spower $x }
msg_srvproc WAVE epower { x } { pmac::comm 0 "m5=$x"; global epower; set epower $x }
msg_srvproc WAVE apower { x } { ljack::setbit 0 0 [expr !($x)]; global apower; set apower $x }
msg_srvproc WAVE bpower { x } { ljack::setbit 0 1 [expr !($x)]; global bpower; set bpower $x }
msg_srvproc WAVE fpower { x } { ljack::setbit 0 3 [expr !($x)]; global fpower; set fpower $x }

proc d2r { deg } {
	return [expr $deg/57.2957795131]
}

msg_srvproc WAVE tposi  { arc } {
    set arcsec $arc
    set arc  [expr $arc / 3600.0]

    set ::tposi $arc

    set sign 1
    if { $arc < 0 } {
	set arc [expr -($arc)]
        set sign -1
    }

	set t_mm [expr 542.34200 * $arc +  7.71084 * $arc * $arc]
	set mdeg [expr   3.04732 * $arc + -0.24853 * $arc * $arc + 2.35851 * $arc *$arc *$arc]

	set c	  -0.0002937720
	set k   -665.0
	set r    [expr   600.598 * $arc + -6.75170 * $arc * $arc + 55.2804 * $arc *$arc *$arc]

	set    f_mm [expr ($c * $r * $r) / (1 + sqrt(1 - (1 + $k) * $c * $c * $r *$r))]

	set t_mm [expr $t_mm * $sign]
	set mdeg [expr $mdeg * $sign * -1]
	set f_mm [expr $f_mm * -1]

	set ::MDeg $mdeg
	set ::TPos $t_mm
	set ::FPos $f_mm

	tmove $t_mm
	mposi $mdeg
	fmove $f_mm

	if { $::slew } {
	    set el [expr $arcsec * cos([d2r $::instangle]) * -1]
	    set az [expr $arcsec * sin([d2r $::instangle]) * -1]
	    puts "boo!"
	    msg_cmd TELESCOPE "instoff $az $el" 10000
	}
}

msg_srvproc WAVE mposi  { deg } {
	set    m_mm [expr tan([d2r $deg]) * 88.9]
#puts $m_mm
	mmove $m_mm
}

msg_srvproc WAVE ppower { x } {
	global punt

    ljack::setbit 0 2 [expr !($x)]; global ppower; set ppower $x
    if { $x } {
	after 10000
        set ::pT 0
        catch { set ::pA [puntino::posi $punt] }
        catch {           puntino::stat $punt  }
    }
}

set spower [pmac::comm 0 "m6"]
set epower [pmac::comm 0 "m5"]
ppower 1
apower 1
bpower 1
fpower 0

set tposi 0.000

msg_publish WAVE spower spower
msg_publish WAVE epower epower
msg_publish WAVE ppower ppower
msg_publish WAVE apower apower
msg_publish WAVE bpower bpower
msg_publish WAVE fpower fpower

msg_publish WAVE tposi tposi

set MDeg 0
set TPos 0
set FPos 0

msg_publish WAVE MDeg MDeg
msg_publish WAVE TPos TPos
msg_publish WAVE FPos FPos

set slew 0
msg_publish WAVE slew slew

foreach { name position gain offset } $Temps {
    msg_publish WAVE $name $name
}

rename tmove _tmove
msg_srvproc WAVE tmove { position } {
    	global cHomed cHFlag cA

    set HFlag [pmac::comm 0 m321]

    if { $HFlag == 1 } {
	if { $cHomed == 0 } { ctags }

        if { $position < -275.0		\
          && $::cA     <    0.0 } {
	    cmove 0.0
	}
    }
    _tmove $position
}

msg_srvproc WAVE home { } {
        ctags
        thome
        chome
        mhome
        fhome
	 stow
}
msg_srvproc WAVE stow { } {
#        fmove    0
	cmove 0.0 
        _tmove -476.5
}

msg_srvproc WAVE ctags { } {
    pmacserv::proginit 0 1
    pmacserv::run      0 3 "1300"
    pmacserv::wait     0 0 20
    pmacserv::progdone 0 3
}

proc rmove { pos } {
        tmove $pos
        mmove    0
}
proc WAVE.rmove { s sock msgid cmd position } {
    rmove $position
    msg_ack $sock $msgid
}
msg_register WAVE rmove

msg_srvproc WAVE selwfs { } { cmove [pmac::comm 0 p90] }
msg_srvproc WAVE selsci { } { cmove [pmac::comm 0 p91] }

msg_srvproc WAVE select { cam } {
    switch $cam {
     wfs {
	set   cpos    [pmac::comm 0 p70]
	set ::toffxxx [pmac::comm 0 p72]
	set ::foffxxx [pmac::comm 0 p74]
     }
     sci {
	set   cpos    [pmac::comm 0 p71]
	set ::toffxxx [pmac::comm 0 p73]
	set ::foffxxx [pmac::comm 0 p75]
     }
    }

    tposi $::tposi
    cmove $cpos
}


# Hook up the puntino stepper stage to server commands.
#
msg_srvproc WAVE phome { }     {
	global punt

    set ::pT 0
    puntino::home $punt
    after 1000
    set ::pA [puntino::posi $punt]
}
msg_srvproc WAVE pmovr { pos } {
	global punt

    set ::pT [expr $::pA+$pos]
    puntino::movr $punt $pos
    set ::pA [puntino::posi $punt]
}
msg_srvproc WAVE pmove { pos } {
	global punt

    set ::pT $pos
    puntino::move $punt $pos
    set ::pA [puntino::posi $punt]
}
msg_srvproc WAVE plite { lit } {
	global punt

    puntino::lite  $punt $lit
    set    ::pLite $lit
}

msg_publish WAVE pA    pA
msg_publish WAVE pT    pT
msg_publish WAVE pLite pLite

catch { set pA    [puntino::posi $punt]
	set pT    [puntino::posi $punt]
	set pLite 0
}



# Hook up the cpu temperature value from the motherboard.
#
msg_publish  WAVE cpuTemp cpuTemp

msg_up       WAVE

set Mux 7
setmux  0



FastUpdate
SlowUpdate
vwait forever

