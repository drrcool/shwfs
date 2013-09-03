
package require critcl
package provide pmac 1.0

namespace eval pmac {
    namespace export {[a-z]*}

    variable  DPRAM
    array set DPRAM {
	estop   { X     0xD290 }
	error	{ X	0xD295 }
	done	{ X	0xD296 }
    }

    proc getX { pmac addr } { getsht $pmac $addr 2 }
    proc getY { pmac addr } { getsht $pmac $addr 0 }
    proc getF { pmac addr } { getflt $pmac $addr   }

  if { ![string compare $tcl_platform(platform) windows] } {
    critcl::clibraries C:\\Windows\\system32\\pmac.dll

    critcl::cproc init { int pmac } int { return OpenPmacDevice(pmac);  }
    critcl::cproc done { int pmac } int { return ClosePmacDevice(pmac); }

    critcl::cproc comm { int pmac char* command } char*  {

	static char buffer[64000];
	int n;

        if ( !(n = PmacGetResponseA(pmac, buffer, 64000, command)) ) { 
	    if ( PmacGetError(pmac) ) return "PMAC Comm Error";
	    else		      return "";
	}

	n--;
	while ( buffer[n] == '\r'
	     || buffer[n] == '\n' ) {
		buffer[n]  = '\0';
		n--;
	}

	return buffer;
    }

    critcl::ccode {
#define NAx 4

	static double C[NAx];
	static double A[NAx];
	static double B[NAx];

	int    geti24(pmac, addr)
		int	pmac;
		int	addr;
	{
	    short  PmacDPRGetWord();
	    short i0;
	    short i1;

	    i0 = PmacDPRGetWord( pmac, (addr - 0xD000)*4 + 0);
	    /* Tcl_Sleep(1); */
	    i1 = PmacDPRGetWord( pmac, (addr - 0xD000)*4 + 2) & 0x00FF;
	    /* Tcl_Sleep(1); */

	    return (i0 & 0xFFFF) | ((int) i1 << 16);
	}

	int    gets24(pmac, addr)
		int	pmac;
		int	addr;
	{
	    int i0 = geti24(pmac, addr);

	    if ( i0 & 0x00800000 ) {
		i0 |= 0xFF000000;
	    }

	    return i0;	
	}

	double geti48(pmac, addr)
		int	pmac;
		int	addr;
	{
	    int i0;
	    int i2;

	    i0 = geti24(pmac, addr  );
	    i2 = gets24(pmac, addr+1);

	    return (i0 & 0x00FFFFFF) + ((double) i2 * 0x00FFFFFF);
	}

	double DPRPosition(pmac, axis, bias)
	    	int	pmac;
		int	axis;
		int	bias;
	{
	    return (geti48(pmac, axis) + geti48(pmac, bias)) / (96*32);
	}
    }

    critcl::cproc back { int pmac int period int motors } void {
	PmacDPRBackground(pmac, motors != 0);
	PmacDPRRealTime(  pmac, period, motors != 0);
	PmacDPRSetMotors( pmac, motors);
    }

    critcl::cproc getsht { int pmac int addr int mem } int {
	short  PmacDPRGetWord();
	return PmacDPRGetWord( pmac, (addr - 0xD000)*4 + mem);
    }
    critcl::cproc geti24 { int pmac int addr } int {
	return geti24(pmac, addr);
    }
    critcl::cproc gets24 { int pmac int addr } int {
	return gets24(pmac, addr);
    }
    critcl::cproc getint { int pmac int addr } int {
	return PmacDPRGetDWord(pmac, (addr - 0xD000)*4);
    }
    critcl::cproc geti48 { int pmac int addr } double {
	return geti48(pmac, addr);
    }
    critcl::cproc getflt { int pmac int addr } double {
	float  PmacDPRGetFloat(), f;
	return PmacDPRGetFloat(pmac, (addr - 0xD000)*4); 
    } 
    critcl::cproc setsht { int pmac int addr int mem int value } void {
	PmacDPRSetWord( pmac, (addr - 0xD000)*4 + mem, (short) value);
    }
    critcl::cproc setint { int pmac int addr int value } void {
	PmacDPRSetDWord(pmac, (addr - 0xD000)*4, value);
    }
    critcl::cproc setflt { int pmac int addr double value } void {
	PmacDPRSetFloat(pmac, (addr - 0xD000)*4, (float) value);
    }
  } else {
    puts "PMAC Faked"

    proc init { pmac } { }
    proc done { pmac } { }
    proc back { pmac period motors } { }
    proc comm { pmac comm } 	  { return 0 	  }
    proc getsht { pmac addr mem } { return [rand] }
    proc getint { pmac addr } 	  { return [rand] }
    proc geti48 { pmac addr } 	  { return [rand] }
    proc getflt { pmac addr }	  { return [rand] }
    proc setsht { pmac addr mem value } { }
    proc setint { pmac addr     value } { }
    proc setflt { pmac addr     value } { }
    critcl::cproc rand { } int { return rand(); }
    proc rand { } { return 1 }
  }

    proc pget { pmac name } {
	variable DPRAM

	set type [lindex $DPRAM($name) 0]
	set addr [lindex $DPRAM($name) 1]

	switch -exact $type {
	    X 	  { return [pmac::getsht $pmac $addr 2]	}
	    Y 	  { return [pmac::getsht $pmac $addr 0]	}
	    int   { return [pmac::getint $pmac $addr] 	}
	    float { return [pmac::getflt $pmac $addr] 	}
	    i48   { return [pmac::geti48 $pmac $addr] 	}
	}
    }

    proc pset { pmac name value } {
	variable DPRAM

	set type [lindex $DPRAM($name) 0]
	set addr [lindex $DPRAM($name) 1]

	switch -exact $type {
	    X     { pmac::setsht $pmac $addr 2 $value 	}
	    Y     { pmac::setsht $pmac $addr 0 $value 	}
	    int   { pmac::setint $pmac $addr $value	}
	    float { pmac::setflt $pmac $addr $value 	}
	    i48   { pmac::seti48 $pmac $addr $value	}
	}

	return $value
    }

    variable Axis { 0xD014 0xD023 0xD032 0xD041 }
    foreach  axis $Axis { variable $axis 0 }

    variable Bias { 0xD095 0xD0B4 0xD0D3 0xD0F2 }
    foreach  bias $Bias { variable $bias 0 }

    variable Sta1 { 0xD01B 0xD02A 0xD039 0xD048 }
    foreach  sta1 $Sta1 { variable $sta1 0 }

    variable Sta2 { 0xD097 0xD0B6 0xD0D5 0xD0F4 }
    foreach  sta2 $Sta2 { variable $sta2 0 }

    variable Bits
    array set Bits [list		\
	PLim 	[expr 1 << 21]		\
	MLim	[expr 1 << 22]		\
	VelZ	[expr 1 << 13]		\
       	IsMov	[expr 1 << 17]		\
	StopLim	[expr 1 << 11]		\
       	FolErr	[expr 1 <<  2]		\
       	InPos	[expr 1 <<  0]		\
	OLop	[expr 1 << 18]		\
    ]

    proc stat { pmac names } {
	variable Axis
	variable Sta1
	variable Sta2
	variable Bias
	variable Bits

        foreach  axis $Axis     \
                 bias $Bias     \
                 sta1 $Sta1     \
                 sta2 $Sta2 {
            variable $axis
            variable $bias
            variable $sta1
            variable $sta2
        }


	set pvars {
			Homed 	01 X	
			HomePos	02 F
			PLimPos	03 F
			MLimPos	04 F
			Brak	05 X
			HFlag	06 X
			PLimit	07 X
			MLimit	08 X
			Check   09 X
			AxisSav 10 X
		    }

	global servo estop
	set servo [pmac::getsht $pmac 0xD009 2]
	set estop [pmac::pget   $pmac estop]

	pmac::setsht $pmac 0xD009 0 0x0000

	foreach name $names		\
	        axis $Axis 		\
		sta1 $Sta1		\
	        bias $Bias 		\
		scal { 666.667 1000 2000 2000 }	\
	        moto { 1 2 3 4 } {

	    global ${name}C
	    global ${name}A
	    global ${name}T
	    global ${name}E
	    global ${name}DAC
	    global ${name}DACBias
	    global Brak

	    set comm [pmac::comm 0 "m${moto}11"]
	    set axis [pmac::comm 0 "m${moto}12"]
	    set targ [pmac::comm 0 "m${moto}13"]
	    set bias [pmac::comm 0 "m${moto}14"]

	    set stat [pmac::geti24 $pmac $sta1]

	pmac::setsht $pmac 0xD08A 0 0x0000

      set ${name}C [format %.3f [expr (( $comm + $bias ) / (96*32.0)) / $scal]]
      set ${name}A [format %.3f [expr (( $axis + $bias ) / (96*32.0)) / $scal]]
      set ${name}T [format %.3f [expr (( $targ + $bias ) / (96*32.0)) / $scal]]

	    set ${name}DAC     [pmac::comm 0 "m${moto}20"]
	    set ${name}DACBias [pmac::comm 0 "i${moto}29"]

	    set EncPower        [pmac::comm 0 "m5"]
	    set ServoPower      [pmac::comm 0 "m6"]
	    set Brak	        [pmac::comm 0 "m7"]

	    set ${name}E [pmac::comm $pmac "#${moto}p"]

	    foreach bit { PLim MLim VelZ IsMov OLop } {
	        global ${name}$bit

	        set ${name}$bit [expr !!($stat & $Bits($bit))]
	    }	    
	    foreach bit { StopLim FolErr InPos } {
	        global ${name}$bit
	        set ${name}$bit [expr !!($sta2 & $Bits($bit))]
	    }	    
	    foreach { vname vnum vtyp } $pvars {
		global $name$vname
		set $name$vname [pmac::get$vtyp $pmac 0xD[expr $moto+4]$vnum]
	    }
	    pmac::setsht $pmac 0xD291 2 0

	    set ${name}PLimit [expr [set ${name}PLimit] 	\
			  	 | ([set ${name}PLim] * 2)]
	    set ${name}MLimit [expr [set ${name}MLimit] 	\
			  	 | ([set ${name}MLim] * 2)]
	}
    }
}

if { 0 } {
    pmac::init 0
    pmac::back 0 20 4

    for { set i 1 } { $i <= 1 } { incr i } {

	    if { [catch { pmac::stat 0 { M T C F } } reply] } {
		    puts "Huh: $reply"
	    }
	    puts "$i: $servo 	M: $MA $MC T: $TA $TC"
	    after 1
    }
}
