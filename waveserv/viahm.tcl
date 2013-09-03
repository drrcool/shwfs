
package require critcl
package provide viahm 1.0

namespace eval viahm {
    namespace export {[a-z]*}

    critcl::clibraries {C:\\VIAhm\\viahm.dll}

    critcl::cproc init {} void {
	VIAHMOpen();
	VIAHMInit();
    }

    critcl::cproc Tsens1 {} int {
	int t = 8;
	VIAHMGetTsens1Reg(&t);

	return ((t - 63) - 32) * 5.0/9.0 + 0.5;
    }
    critcl::cproc Tsens2 {} int {
	int t;
	VIAHMGetTsens2Reg(&t);

	return ((t - 63) - 32) * 5.0/9.0 + 0.5;
    }
}

