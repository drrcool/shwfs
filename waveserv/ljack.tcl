
package require critcl
package provide ljack 1.0

namespace eval ljack {
    namespace export {[a-z]*}

    critcl::clibraries C:\\Windows\\system32\\ljackuw.dll

    critcl::ccode {
	static long dddirs = 0;
	static long iodirs = 0;
    }

    critcl::cproc init { int jak } float {
	float GetFirmwareVersion();

	 return GetFirmwareVersion(&jak);
    }

    critcl::cproc getbit { int jak int bit } int {
	int dio, state = 0, err;

	if ( bit < 16 ) {
		dio  = 1;
	} else {
		bit -= 16;
		dio  = 0;
	}
	if ( err = EDigitalIn(&jak, 0, bit, dio, &state) ) 
	    return 0x8000 | err;

	return state;
    }
    critcl::cproc setbit { int jak int bit int state } int {
	int dio, err;

	if ( bit < 16 ) {
		dio  = 1;
	} else {
		bit -= 16;
		dio  = 0;
	}
	return EDigitalOut(&jak, 0, bit, dio, state);
    }
    critcl::cproc getvolt { int jak int chan int gain } float {
	long 	over;
	float	volt;
	int	errn;

	if ( errn = EAnalogIn(&jak, 0, chan, gain, &over, &volt) )
	    return errn;

	if ( over ) return -101.0;

	return volt;
    }
    critcl::cproc setvolt { int jak float out1 float out2 } int {
	return EAnalogOut(&jak, 0, out1, out2);
    }
}

# Test by power cycling the puntino
#
#puts [ljack::init 0]
#puts [ljack::setbit 0 4 1]	; after 2000
#puts [ljack::setbit 0 4 0]	; after 2000
#puts [ljack::setbit 0 4 1]	; after 2000

#after 10000000
