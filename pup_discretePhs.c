/* pup_discretePhs.c; scw: 8-12-99 update: 8-17-00*/

/* pup_discretePhs.c is a routine that generates a view of the results of
 * the phase solve consisting of discrete points on the pupil.  It reads a
 * .phs file which is a list of x,y,phs at the Hartmann mask locations in
 * the pupil.  It renders a square grid for making an XPM file.  The pupil
 * phases are plotted at their appropriate locations and the color map is
 * scaled just to these points. */

/* This routine requires a poly_mask string consisting of ZPOLY characters
 * that are either 0 or 1 and a file.zph containing the zernike coefficients
 * of the fit to this phase distribution.  Using the poly_mask string, the
 * selected zernike mode phases are subtracted from the discrete phase
 * distribution, and an XPM file of the result is formed.  */

/* The sense of the poly_string passed from tcl is that a 1 means you want
 * to see this mode's phase in the XPM file (i.e., it's visible) and a 0 if
 * you want the mode removed from the phase distribution.  Note that the
 * poly_mask is inverted prior to calling createPhaseVector, because that
 * routine is summing the phases that are to be subtracted from the raw
 * phases. In this way, if the tcl checkbox is ON (mask=1), the phase is
 * seen in the XPM image.  */


/* This routine returns a string via a pipe to the calling tcl code.  That
 * string consists of ZPOLY + 1 float values that are the rms phase errors
 * from the ZPOLY zernike modes and the residual uncorrected phase error
 * evaluated at the hartmann aperture pupil locations. NOTE: it returns the
 * rms errors for all ZPOLY modes--not just the unmasked ones. */

/* starting at 8-4-99, code is added to calculate the image psf from the
 * pupil phase error distribution.  This uses psf() in WFSlib.c. */

 #include <stdio.h>
 #include <stdlib.h>
 #include <math.h>
 #include "fileio.h"
 #include "zernike.h"
 #include "WFSlib.h"
 #include "nrutil.h"
 #define MAIN
 #include "optics.h"

 /* argv[1] = file.phs, 
 argv[2] = file.zph, 
 argv[3] = poly mask,	
 argv[4] = ds,			detector shift microns
 argv[5] = field,		CCD field size arcsec
 argv[6] = range,		% of max intensity to display
 argv[7] = rms_calc,	0=calc all mode rms's, 1= residual only */
 
 main (int argc, char *argv[])
 {
 	int i, j,k,y,z,I,J;

	const int RPUP = 100;	/* resolution elements along pupil radius */
	const int SZ = 2*RPUP*2*RPUP; /* size for 1D vectors to hold 2D data */
	const int blur = 1;			/* widen each phase pixel by +/- blur */
	const int det_size = 50;	/* # image pixels in x and y */
	const int Npixels = det_size * det_size;
	
	char *mask = argv[3];
	char *tmp, c[2] = {5,0};

	int napts,cols,	/* # of rows, cols in .phs file */
		*vmask,		/* vectorized poly_mask */
		rng, rms_calc;

	float *phs,
		*zrn,
		**xyp,	/* hold all xy,phase values */
		**xy,		/* xy aperture coords */
		**ppimg,		/* XPM image array */
		sum, sum2, mean, resid_rms,	/* summing registers for rms calculation */
		*mode_rms, *cmode_rms,
		*Px, *Py, *Pphs, *detx, *dety, *detI, **psfimg,
		pix_size, field, ds;

	zrn = vector (1, ZPOLY); 
	readVector (argv[2], zrn, ZPOLY);	/* read in zernike poly coeffs */

	fileDim (argv[1], &napts, &cols);
	xyp = matrix (1, napts, 1, 3);
	
	readMatrix (argv[1], xyp, napts, 3); /* read in x,y,raw phase values */

	vmask = ivector (1, ZPOLY);
	/* convert the string mask to an integer vector mask */
	tmp = mask;
	for (i=1;i<=ZPOLY;i++)
	{
		c[0] = *tmp++;
		vmask[i] = atoi(c);	/* atoi needs a string! */
		vmask[i] = (vmask[i] == 0) ? 1 : 0; /* invert vmask */
	}

	field = atof(argv[5]);
	ds = atof(argv[4]);
	rng = atoi(argv[6]);
	rms_calc =atoi(argv[7]);

	pix_size = field*um_as/det_size;
	

	/* strip xy coords from the xyp array */
	xy = matrix (1,napts, 1,2);

	for (i=1;i<=napts;i++)
	{
		xy[i][1] = xyp[i][1];
		xy[i][2] = xyp[i][2];
	}
		
	/* using mask, subtract desired mode phases from the raw phases */
	phs = vector (1, napts);
	/* get mode phases to subtract */
	createPhaseVector (zrn, xy, napts, phs, vmask);

	for (i=1;i<=napts;i++)
		xyp[i][3] -= phs[i];	/* do phase subtraction of zernike modes
									from the raw phases. */


	 /* make the initial XPM grid, and set all pixels to transparent */
	 ppimg = matrix(1,2*RPUP,1,2*RPUP);
	 for (i=-RPUP;i<RPUP;i++)
	 	for (j=-RPUP;j<RPUP;j++)
			ppimg[i+RPUP+1][j+RPUP+1] = -100000;
			
	/* map xy coords into the XPM image */
	/* put in the discrete phase points by writing over the appropriate
	 * locations. */
	 for (k=1;k<=napts;k++)
	 {
	 	I = xyp[k][1]*(float)RPUP * .95;
		J =  xyp[k][2]*(float)RPUP * .95;
		/* keep the image inside the array indices (not very clean for now) */
		/* if (i > RPUP-1) i = RPUP-1;
		if (i < -RPUP) i = -RPUP;
		if (j > RPUP-1) j = RPUP-1;
		if (j < -RPUP) j = -RPUP;
		ppimg[i+RPUP+1][j+RPUP+1] = xyp[k][3]; */

		/* the above creates a single pixel in the image which is too
		 * small--need to blur each one out to the surrounding pixels */
		for (y=-blur;y<=blur;y++)
		{
			i = I + y;
			for (z=-blur; z<=blur;z++)
			{
				j = J + z;
				ppimg[i+RPUP+1][j+RPUP+1] = xyp[k][3];
			}
		}
				
		
	}
	 	
	makeXPM (ppimg, 2*RPUP, 2*RPUP, 0, 100, 1, "wavefront.xpm");

	/* return the rms values via the pipe */
	/* calc the residual rms */
	sum = sum2 = 0;
	for (i=1;i<=napts;i++)
	{
		sum += xyp[i][3];
		sum2 += xyp[i][3] * xyp[i][3];
	}
	mean = sum/napts;
	resid_rms = sqrt (sum2/napts - 2*mean*mean + mean*mean);

	if (rms_calc == 0)	/* get all mode rms errors */
	{
		mode_rms = vector (1, ZPOLY);
		cmode_rms = vector (1, 7);
		phaseRMS (xy, napts, zrn, mode_rms);

		cmode_rms[1] = hypot (mode_rms[1], mode_rms[2]);	/*tilt*/
		cmode_rms[2] = mode_rms[3];
		cmode_rms[3] = hypot (mode_rms[4], mode_rms[5]);	/*astig*/
		cmode_rms[4] = hypot (mode_rms[6], mode_rms[7]);	/*coma*/
		cmode_rms[5] = mode_rms[8];
		cmode_rms[6] = hypot (mode_rms[9], mode_rms[10]);	/*trefoil*/
		cmode_rms[7] = hypot (mode_rms[11], mode_rms[12]);	/*quad astig*/


		for (i=1;i<=7;i++)
			printf ("%5.0f ", cmode_rms[i]);
	}


	printf ("%5.0f", resid_rms);

/* this section sets up the data needed for the PSF image calculation and
 * production of the XPM image. */

 /* break up pupil coords into vectors (required by psf.c), and re-scale to
  * the actual entrance aperture size.  NOTE: The pointers passed are
  * strange because psf() has 0-based arrays. */

 Px = vector (1, napts);
 Py = vector (1, napts);
 Pphs = vector(1, napts);

 for (i=1;i<=napts;i++)
 {
 	Px[i] = xyp[i][1] * ERAD;	/* re-scale pupil coords */
	Py[i] = xyp[i][2] * ERAD;
	Pphs[i] = xyp[i][3]/1000; 	/* convert phases from nm to um */
  }

  detx = vector (1, Npixels);
  dety = vector (1, Npixels);
  detI = vector (1, Npixels);

  /* define the detector coordinates */

	k=1;
	for (i= -det_size/2;i<det_size/2;i++)
		for (j= -det_size/2;j<det_size/2;j++)
		{
			detx[k] = i*pix_size;
			dety[k++] = j*pix_size;
		}
	if (k - 1 != Npixels) 
	{printf ("detector messed up\n"); return (0); }

	psf (FL, ds, 0.8, napts, &Pphs[1], &Px[1], &Py[1], Npixels, &detI[1],
	&detx[1], &dety[1]);

	/* now make the psf image */
	psfimg = matrix (1, det_size, 1, det_size);
	k=1;
	for (i= -det_size/2;i<det_size/2;i++)
		for (j= -det_size/2;j<det_size/2;j++)
		{
			psfimg[i + det_size/2 +1][j +det_size/2 + 1] = detI[k++];
		}
		
	/* writeMatrix ("psfimg", psfimg, det_size, det_size); */
	makeXPM (psfimg, det_size, det_size, 0, rng, 3, "psf.xpm"); 



	
free_vector (zrn, 1, ZPOLY); 
free_ivector (vmask, 1, ZPOLY);
free_matrix (xyp,1,napts,1,3);
free_matrix (xy, 1, napts, 1, 2);
free_vector (phs, 1, napts);
free_matrix (ppimg,1,2*RPUP,1,2*RPUP);
if (rms_calc == 0)
{
	free_vector (mode_rms, 1, ZPOLY);
	free_vector (cmode_rms, 1, 7);
}

free_vector (Px, 1, napts);
free_vector (Py, 1, napts);
free_vector (Pphs, 1, napts);
free_vector (detx, 1, Npixels);
free_vector (dety, 1, Npixels);
free_vector (detI, 1, Npixels);
free_matrix (psfimg, 1, det_size, 1, det_size);

return (0);
}
