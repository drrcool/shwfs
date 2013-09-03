
#define TARGET ENV_WIN

#define SBIG(interp, cmd, in, out) {						\
    	    int err;								\
										\
	if ( (err = SBIGUnivDrvCommand(cmd, (void *) in, (void *) out)		\
	    != CE_NO_ERROR) ) {							\
	    GetErrorStringParams  errin;					\
	    GetErrorStringResults errot;					\
										\
	    *errot.errorString = '\0';						\
	    									\
	    errin.errorNo = err;						\
	    SBIGUnivDrvCommand(CC_GET_ERROR_STRING, (void *) &errin, (void *) &errot);	\
	    Tcl_SetResult(interp, (char *) &errot.errorString, TCL_VOLATILE); 		\
	    return TCL_ERROR;							\
	}									\
}

#define StartReadout(interp, bin, x1, y1, nx, ny) {				\
	    StartReadoutParams  in;						\
										\
	    in.ccd		= 0;						\
	    in.readoutMode	= bin - 1;					\
	    in.top		= x1;						\
	    in.left		= y1;						\
	    in.height		= nx;						\
	    in.width		= ny;						\
										\
	    SBIG(interp, CC_START_READOUT, &in, NULL);				\
}

#define DumpLines(interp, bin, y1) {						\
	    DumpLinesParams     in;						\
										\
	    in.ccd		= 0;						\
	    in.readoutMode	= bin - 1;					\
	    in.lineLength	= y1;						\
										\
	    SBIG(interp, CC_DUMP_LINES, &in, NULL);				\
}

#define ReadLine(interp, bin, x1, nx, here) {					\
	ReadoutLineParams   in;							\
										\
	in.ccd		= 0;							\
	in.readoutMode	= bin - 1;						\
	in.pixelStart	= x1;							\
	in.pixelLength	= nx;							\
										\
	SBIGUnivDrvCommand(CC_READ_SUBTRACT_LINE, &in, here);		\
}

#define ReadEnd(interp)	{							\
	EndReadoutParams  in;							\
										\
	in.ccd  	= 0;							\
										\
	SBIG(interp, CC_END_READOUT, &in, NULL);				\
}

#define Cooler(interp, onoff, T) {						\
	    SetTemperatureRegulationParams     in;				\
										\
	    in.regulation	= onoff;					\
	    in.ccdSetpoint	= T;						\
										\
	    SBIG(interp, CC_SET_TEMPERATURE_REGULATION, &in, NULL);		\
}

#define Temperature(interp, onoff, A, T) {					\
	    QueryTemperatureStatusResults     out;				\
										\
	    SBIG(interp, CC_QUERY_TEMPERATURE_STATUS, NULL, &out);		\
	    onoff = out.enabled;						\
	    A     = out.ambientThermistor;					\
	    T     = out.ccdThermistor;						\
}

#define TclReturnOK(interp)							\
	Tcl_SetResult(interp, NULL, NULL);					\
	return TCL_OK;

#define TclReturnInt(interp, i) {                                               \
    	Tcl_Obj *obj = Tcl_GetObjResult(interp);                        	\
	Tcl_SetIntObj(obj, i);                                          	\
	return TCL_OK;                                                     	\
}

