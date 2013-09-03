
package require critcl
package provide bob	1.0

namespace eval bob {
    namespace export {[a-z]*}
    critcl::cproc get { Tcl_Interp* interp int att int off int len } ok {
	Tcl_SetObjResult(interp, Tcl_NewByteArrayObj((char *) att + off, len));
	return TCL_OK;
    }
    critcl::cproc set { Tcl_Interp* interp int att int off int len char* data } void {
	strncpy((char *) att + off, data, len);
    }
    critcl::ccommand write { data interp objc objv } {
	char *att;
	int   off;
	int   len;
	Tcl_Channel ofp;

	int   mode;

	if ( objc != 5 ) {
	    Tcl_SetResult(interp, "shm::frfp att offset length file", TCL_STATIC);
	    return TCL_ERROR;
	}
	Tcl_GetIntFromObj(interp, objv[1], &att);
	Tcl_GetIntFromObj(interp, objv[2], &off);
	Tcl_GetIntFromObj(interp, objv[3], &len);
	if ( (ofp = Tcl_GetChannel(interp, Tcl_GetString(objv[4]), &mode)) == NULL ) {
	    Tcl_SetResult(interp, "shm::frfp cannot get channel", TCL_STATIC);
	    return TCL_ERROR;
	}
	Tcl_Write(ofp, att + off, len);
	return TCL_OK;
    }

    critcl::ccommand read { data interp objc objv } {
	char *att;
	int   off;
	int   len;
	Tcl_Channel ifp;

	int   mode;

	if ( objc != 5 ) {
	    Tcl_SetResult(interp, "shm::frfp att offset length file", TCL_STATIC);
	    return TCL_ERROR;
	}
	Tcl_GetIntFromObj(interp, objv[1], &att);
	Tcl_GetIntFromObj(interp, objv[2], &off);
	Tcl_GetIntFromObj(interp, objv[3], &len);
	if ( (ifp = Tcl_GetChannel(interp, Tcl_GetString(objv[4]), &mode)) == NULL ) {
	    Tcl_SetResult(interp, "shm::frfp cannot get channel", TCL_STATIC);
	    return TCL_ERROR;
	}
	Tcl_Read(ifp, att + off, len);
	return TCL_OK;
    }
}
