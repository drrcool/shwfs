

package require critcl
package provide pixelink 1.0

namespace eval pixelink {
    namespace export {[a-z]*}

    critcl::clibraries {C:\\Windows\\system32\\PimMegaApi.dll}
    critcl::ccode {
	char  *pix_buff = NULL;
	int    pix_x1    = 0;
	int    pix_y1    = 0;
	int    pix_bin   = 1;
	int    pix_xdata = 1280;
	int    pix_ydata = 1024;

	int    pix_size;
	int    pix_bitpix;
	double pix_exptime = 0.0;
	int    pix_video;
	void  *pix_cam;

	void swap2shift(buff, npix)
		unsigned short *buff;
		int    npix;
	{
	    char c;
	    int i;

	    for ( i=0; i < npix; i++, buff++ ) {
		*buff >>= 6;

		c = *((char *) buff);
		*((char *) buff)   = *((char *) buff+1);
		*((char *) buff+1) = c;
	    }
	}

    }

    proc nx    { } { return 1280; }
    proc ny    { } { return 1024; }

    critcl::cproc x1    { } int { return pix_x1; }
    critcl::cproc y1    { } int { return pix_y1; }
    critcl::cproc xdata { } int { return pix_xdata; }
    critcl::cproc ydata { } int { return pix_ydata; }
    critcl::cproc xbin  { } int { return pix_bin; }
    critcl::cproc ybin  { } int { return pix_bin; }

    critcl::cproc W { } int { return pix_xdata; }
    critcl::cproc H { } int { return pix_ydata; }
    critcl::cproc B { } int { return pix_bitpix; }
    critcl::cproc init { Tcl_Interp* interp int camera } ok {
	__attribute__((stdcall)) _PimMegaInitialize(char *, int, void *); 
	__attribute__((stdcall)) _PimMegaSetVideoMode(void *, int);
	__attribute__((stdcall)) _PimMegaSetDataTransferSize(void *, int);
	__attribute__((stdcall)) _PimMegaStartVideoStream(void *);

	int   err;
	Tcl_Obj *obj = Tcl_GetObjResult(interp);

	if ( err = _PimMegaInitialize(
		"PixelLINK(tm) 1394 Camera", camera, &pix_cam) ) {

	    Tcl_SetIntObj(obj, err);
	    return TCL_ERROR;
	}
	pix_bitpix = 16;

	if ( err = _PimMegaSetDataTransferSize((void*) pix_cam, pix_bitpix) ) {
	    Tcl_SetIntObj(obj, err);
	    return TCL_ERROR;
	}

	pix_video = 1;

	if ( err = _PimMegaSetVideoMode((void*) pix_cam, 1) ) {
	    Tcl_SetIntObj(obj, err);
	    return TCL_ERROR;
	}
	if ( err = _PimMegaStartVideoStream(pix_cam) ) {
	    Tcl_SetIntObj(obj, err);
	    return TCL_ERROR;
	}

	Tcl_SetIntObj(obj, (int) pix_cam);
	return TCL_OK;
    }

    proc link { } { }
    proc abort { } { }

    proc param { name value } {
	switch $name {
	    gain	{ pixelink::gain $value }
	    default	{ error "no param $name" }
	}
    }

    proc stat { state } {
	switch $state {
	  Idle 		{ return Idle 	 }
	  Exposing 	{ return Exposed }
	  Reading 	{ return Read	 }
	}
    }
    critcl::cproc preview { char* name } void {
	__attribute__((stdcall))
		_PimMegaStartPreview(void *,
		char * title,
		int style,
		int ,
		int ,
		int ,
		int ,
		void*,
		int,
		int,
		int);

	_PimMegaStartPreview((void*) pix_cam, name, 0, 10, 10, -1, -1, NULL, 0, -1, -1);
    }
    critcl::cproc bitpix { bpix } void {
	pix_bitpix = bpix;
	__attribute__((stdcall)) _PimMegaSetDataTransferSize(void *, int);

	_PimMegaSetDataTransferSize((void*) pix_cam, pix_bitpix);
    }
    critcl::cproc gain { int gain } void {
	__attribute__((stdcall)) _PimMegaSetMonoGain(void *, int);

	_PimMegaSetMonoGain((void*) pix_cam, gain);
    }
    proc info { n } {
	return ""
    }
    critcl::cproc expose { Tcl_Interp* interp char* exptype double expose } ok {
	__attribute__((stdcall)) _PimMegaSetExposureTime(void *, float, int);

	int   err;


	if ( pix_exptime != expose ) {
		if ( err = _PimMegaSetExposureTime((void*) pix_cam, (float) expose, 1) ) {
		    Tcl_Obj *obj = Tcl_GetObjResult(interp);
		    Tcl_SetIntObj(obj, err);
		    return TCL_ERROR;
		}
	}
	pix_exptime = expose;

	return TCL_OK;
    }

    critcl::cproc pause  { int onoff } void {
	__attribute__((stdcall)) _PimMegaPauseVideoStream(void *, int);

	pix_video = onoff;

	_PimMegaPauseVideoStream(pix_cam, onoff); 
    }
    critcl::cproc stream { int onoff } void {
	__attribute__((stdcall)) _PimMegaStartVideoStream(void *);
	__attribute__((stdcall)) _PimMegaStopVideoStream(void *);

	pix_video = onoff;

	if ( onoff ) {
	    _PimMegaStartVideoStream(pix_cam); 
	} else 	     {
	    _PimMegaStopVideoStream( pix_cam); 
	}
    }

    critcl::cproc window { Tcl_Interp* interp int x int y int w int h int b } ok {
	__attribute__((stdcall)) _PimMegaSetSubWindow(void *, int
		, int, int, int, int);
	int err;

	if ( err = _PimMegaSetSubWindow((void*) pix_cam, b, x, y, w, h) ) {
	    Tcl_Obj *obj = Tcl_GetObjResult(interp);
	    Tcl_SetIntObj(obj, err);
	    return TCL_ERROR;
	}

	pix_x1    = x;
	pix_y1    = y;
	pix_bin   = b;
	pix_xdata = (w/(b*8))*8;
	pix_ydata = (h/8)*8/b;
	pix_size  = pix_xdata * pix_ydata;

	Tcl_SetResult(interp, NULL, NULL);
	return TCL_OK;
    }

    proc getbox { n } {
	list 	x1    [pixelink::x1]	\
		xdata [pixelink::xdata]	\
		xbin  [pixelink::xbin]	\
		y1    [pixelink::y1]	\
		ydata [pixelink::ydata]	\
		ybin  [pixelink::ybin]
    }
    proc setbox { n x1 xdata xbin y1 ydata ybin } {
	pixelink::window $x1 $y1 [expr $xdata * $xbin] [expr $ydata * $ybin] $xbin
	pixelink::getbox $n
    }

    critcl::cproc data { Tcl_Interp* interp int n } ok {
	__attribute__((stdcall)) _PimMegaReturnStillFrame(void *, char *, float
		, int, float, int, float, float);
	__attribute__((stdcall)) _PimMegaReturnVideoData(void *, int, void *);

	Tcl_Obj *obj = Tcl_GetObjResult(interp);
	int      err;

	if ( pix_buff == NULL ) {
	    pix_buff = malloc(1280 * 1024 * 2);
	}


	memset(pix_buff, 0, 1280 * 1024 * 2);

	if ( pix_video == 0 ) {
	    err = _PimMegaReturnStillFrame(pix_cam, pix_buff, pix_exptime
		, 0, (float) 0.0, 0, (float) 0.0, (float) 0.0) + 128;
	} else {
	    err = _PimMegaReturnVideoData(pix_cam, pix_size * pix_bitpix/8, pix_buff);
	}
	if ( err ) {
	    Tcl_SetIntObj(obj, err + pix_video * 1000);
	    return TCL_ERROR;
	}

	if ( pix_bitpix == 16 ) { swap2shift(pix_buff, pix_size); }

	Tcl_SetByteArrayObj(obj, pix_buff, pix_size * (pix_bitpix/8));
	return TCL_OK;
    }

    critcl::cproc size { } int { return pix_size; }

    proc temp { } { return 0 }
    proc setp { } { }
    proc read { } { }

    critcl::cproc datap { Tcl_Interp* interp } ok {
	__attribute__((stdcall)) _PimMegaReturnVideoData(void *, int, void *);

	Tcl_Obj *obj = Tcl_GetObjResult(interp);
	int      err;

	if ( pix_buff == NULL ) {
	    pix_buff = malloc(1280 * 1024 * 2);
	}

	if ( err = _PimMegaReturnVideoData(pix_cam, pix_size, pix_buff) ) {
	    Tcl_SetIntObj(obj, err);
	    return TCL_ERROR;
	}

	Tcl_SetIntObj(obj, pix_buff);
	return TCL_OK;
    }

}

