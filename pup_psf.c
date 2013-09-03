/* pup_psf.c; scw: 8-05-99 */

/* pup_psf.c is a routine for generating pupil phase maps and image PSFs
 * given a vector of Zernike polynomials. It creates an arbitrary grid of
 * pupil coordinates at which to evaluate the zernike phase. After masking
 * out the pupil points from a square grid, it calls makeXPM which creates
 * and image file of the results. This routine is for viewing smooth zernike
 * modes only, and is not to be used for processing of discrete phases
 * (except to view the zernike polynomial fit to those phases).*/

/* The poly_mask string consists of ZPOLY characters that are either 0 or 1.
 * If zero, that particular polynomial term is not included in the phase
 * sum. So only those modes whose mask value is 1 are shown in the XPM
 * image. */

/* the routine returns ZPOLY + 1 string of floats via a pipe which show the
 * rms phase error of each zernike mode, and then the total rms of all the
 * active zernikes added together in the XPM image. */

/* starting at 8-5-99, the code adds a call to psf() in WFSlib.c which
 * calculates the psf image from the pupil phase error distibution. */

/* 1-10-02: moved all files from c_devel to current directory */

/* 5-30-02: added a mod for shwfs which uses the ihwfs apts.cntr file for
 * the wavefront re-sampling for the psf calculation. 
 */

 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
 #include <math.h>
 #include "fileio.h"
 #include "zernike.h"
 #include "WFSlib.h"
 #include "nrutil.h"
 #define MAIN
 #include "optics.h"

 /* pass the arguments as
 argv[1] =.zrn filename,
 argv[2] =poly_mask string, 
 argv[3] = ds, 			detector shift microns 
 argv[4] = field, 		CCD field size arcsec
 argv[5] = range 		% of max intensity to display 
 argv[6] = rms_calc		0 means calc all mode rms errors, 1 = combined rms */

 main (int argc, char *argv[])
 {
   int i, j, k,
     xycntr, pcntr, cntr, cntr2;

   const int RPUP = 50;	/* resolution elements along pupil radius */
   const int SZ = 2*RPUP*2*RPUP; /* size for 1D vectors to hold 2D data */
   const int det_size = 50;	/* # image pixels in x and y */
   const int Npixels = det_size * det_size;

   char *mask = argv[2];
   char *tmp, c[2] = {5,0};
   char *wfsroot, *apts_cntr;

   int *vmask,
     *inpup,		/* in pupil = 1, not = 0 */	
     napts,		/* number hartmann apertures for psf calc */
     rng, rms_calc;

   float *phs,
     *zrn,
     *xp,*yp,	/* hold all xy coords */
     **xy,
     *r, *th,
     **ppimg,
     sum, sum2, mean, tot_rms, *mode_rms, *cmode_rms,
     **hapts, *hx, *hy, *hphs, *detx, *dety, *detI, **psfimg,
     pix_size, field, ds;

   xp = vector (1, SZ);
   yp = vector (1, SZ);
   r = vector (1, SZ);
   th = vector (1, SZ);
   inpup = ivector (1, SZ);
   
   zrn = vector (1, ZPOLY); 
   readVector (argv[1], zrn, ZPOLY);	/* read in zernike poly coeffs */

   vmask = ivector (1, ZPOLY);
   /* convert the string mask to an integer vector mask */
   tmp = mask;
   for (i=1;i<=ZPOLY;i++)
     {
       c[0] = *tmp++;
       vmask[i] = atoi(c);	/* atoi needs a string! */
     }

   field = atof(argv[4]);	/* catch field size */
   ds = atof (argv[3]);
   rng = atoi(argv[5]);
   rms_calc = atoi (argv[6]);

   pix_size = field*um_as/det_size;


   /* Now construct a list of dimensionless pupil coords to evaluate the
    * phases at. Start with a 100 x 100 square grid and determine which
    * coords are inside of the pupil. Send those to createPhaseVector to
    * get the results. */
   
   /* make a list of all xy coords -- saved for XPM conversion.*/
   xycntr = 1;	
   pcntr = 1;		/* count points inside of pupil */
   for (i=-RPUP;i<RPUP;i++)
     {
       for (j=-RPUP;j<RPUP;j++)
	 {
	   /* find x,y,r,th of each point in the grid */
	   /* inpup[] has flag for whether point is within the obstructed
	    * pupil (1) or not (0). */

	   xp[xycntr] = (float)i/(float)RPUP; 
	   yp[xycntr] = (float)j/(float)RPUP;
	   /* dimnless xy */

	   r[xycntr] = hypot (xp[xycntr], yp[xycntr]);
	   th[xycntr] = atan2 (yp[xycntr], xp[xycntr]);
	 
	   if (r[xycntr] <= 1 && r[xycntr] > COBS) 
	     { inpup[xycntr] = 1; pcntr++; }
	   xycntr++;
	 }
     }

   /* now make continuous list of those coords that are within the pupil */
	 
   xy = matrix (1, pcntr-1, 1,2); /* allocate space for x,y coords that
										are inside of the pupil */
   phs = vector (1,pcntr-1);	/* storage for phase output */

   cntr = 1;
   for (i=1;i<xycntr;i++)
     {
       if (inpup[i] == 1) {
	 xy[cntr][1] = xp[i];
	 xy[cntr++][2] = yp[i];
       }
     }
				
   createPhaseVector (zrn, xy, pcntr-1, phs, vmask); 

   /* create a 2D array of intensity values for construction of the image.*/
   ppimg = matrix(1,2*RPUP,1,2*RPUP);
   cntr=1; cntr2 = 1;
   for (i=-RPUP;i<RPUP;i++)
     {
       for (j=-RPUP;j<RPUP;j++)
	 {
	   /* can't have negative indices */
	   ppimg[i+RPUP+1][j+RPUP+1] = (inpup[cntr++] == 0) ? -100000 : phs[cntr2++]; 
	 }
     }

   makeXPM (ppimg, 2*RPUP, 2*RPUP, 0, 100, 2, "wavefront.xpm");

   
   /* return the rms values through the pipe -- but before returning them,
    * combine the mode pairs into a single rms. */
   /* find the total rms of the XPM image = selected modes */
   sum = sum2 = 0;
   for (i=1;i<=pcntr-1;i++)
     {
       sum += phs[i];
       sum2 += phs[i] * phs[i];
     }
   mean = sum/(pcntr-1);
   tot_rms = sqrt (sum2/(pcntr-1) - mean*mean);

   if (rms_calc == 0) /* get all mode rms errors */
     {
       mode_rms = vector (1, ZPOLY);
       cmode_rms = vector (1, 11);
       phaseRMS (xy, pcntr-1, zrn, mode_rms);

       /* 10-28-00: I'm not sure that hypotting mode rms's is accurate */
       cmode_rms[1] = hypot (mode_rms[1], mode_rms[2]);	/*tilt*/
       cmode_rms[2] = mode_rms[3];				/* defocus */
       cmode_rms[3] = hypot (mode_rms[4], mode_rms[5]);	/*astig*/
       cmode_rms[4] = hypot (mode_rms[6], mode_rms[7]);	/*coma*/
       cmode_rms[5] = mode_rms[8];
       cmode_rms[6] = hypot (mode_rms[9], mode_rms[10]);	/*trefoil*/
       cmode_rms[7] = hypot (mode_rms[11], mode_rms[12]);	/*5th order astig*/
       cmode_rms[8] = hypot (mode_rms[13], mode_rms[14]); /* 4-theta */
       cmode_rms[9] = hypot (mode_rms[15], mode_rms[16]); /* 5th trefoil */
       cmode_rms[10] = hypot(mode_rms[17], mode_rms[18]); /* 5th coma */
       cmode_rms[11] = mode_rms[19];

       /* return mode rms's to the pipe */
       for (i=1;i<=11;i++)
	 printf ("%5.0f ", cmode_rms[i]);
     }

   printf ("%5.0f", tot_rms);

   /* this section calculates the image PSF.  First the pupil must be
    * resampled at a lower resolution to control the calculation time. This
    * is just done by reading the xy coordinates of the hartmann masks from
    * a file--this way the central obstruction is included in the psf. */

   /* now get the path to aperture centers file from the environment
    * or assume it's installed in the normal /mmt hierarchy.
    * TEP (2003-03-13)
    */
   if (getenv("WFSROOT")) {
     wfsroot = getenv("WFSROOT");
     apts_cntr = (char *) malloc(strlen(wfsroot) + 11);
     strcpy(apts_cntr, wfsroot);
     strcat(apts_cntr, "/apts.cntr");
   } else {
     apts_cntr = "/mmt/shwfs/apts.cntr";
   }
   fileDim (apts_cntr, &napts, &i);
   hapts = matrix (1, napts, 1, 2);
   hx = vector (1, napts);
   hy = vector (1, napts);
   hphs = vector (1, napts);
   readMatrix (apts_cntr, hapts, napts, 2);

   createPhaseVector (zrn, hapts, napts, hphs, vmask);
	 
   /* create separate hartmann x and y coord vectors for below */
   for (i=1;i<=napts;i++)
     {
       hx[i] = hapts[i][1];
       hy[i] = hapts[i][2];
     }


   for (i=1;i<=napts;i++)
     {
       hphs[i] /= 1000;	/* convert phase errors from nm to um */
       hx[i] *= ERAD;		/* rescale pupil */
       hy[i] *= ERAD;	
     }


   detx = vector (1, Npixels);
   dety = vector (1, Npixels);
   detI = vector (1, Npixels);

   /* define the detector coordinates */

   k=1;
   for (i= -det_size/2;i<det_size/2;i++)
     {
       for (j= -det_size/2;j<det_size/2;j++)
	 {
	   detx[k] = i*pix_size;
	   dety[k++] = j*pix_size;
	 }
     }

   if (k - 1 != Npixels) 
     {printf ("detector messed up\n"); return (0); }

   psf (FL, ds, 0.8, napts, &hphs[1], &hx[1], &hy[1], Npixels, &detI[1],
	&detx[1], &dety[1]);

   /* now make the psf image */
   psfimg = matrix (1, det_size, 1, det_size);
   k=1;
   for (i= -det_size/2;i<det_size/2;i++)
     {
       for (j= -det_size/2;j<det_size/2;j++)
	 {
	   psfimg[i + det_size/2 +1][j +det_size/2 + 1] = detI[k++];
	 }
     }
   
   /* writeMatrix ("psfimg", psfimg, det_size, det_size); */
   makeXPM (psfimg, det_size, det_size, 0, rng, 3, "psf.xpm"); 


   free_vector (zrn, 1, ZPOLY); 
   free_ivector (vmask, 1, ZPOLY);
   free_ivector (inpup, 1, SZ);
   free_vector (xp,1,SZ);
   free_vector (yp,1,SZ);
   free_vector (r, 1, SZ);
   free_vector (th, 1, SZ);
   free_matrix (xy, 1, pcntr-1, 1, 2);
   free_vector (phs, 1, pcntr-1);
   free_matrix (ppimg,1,2*RPUP,1,2*RPUP);
   if (rms_calc == 0)
     {
       free_vector (mode_rms, 1, ZPOLY);
       free_vector (cmode_rms,1,11);
     }

   free_matrix (hapts, 1, napts, 1, 2);
   free_vector (hx, 1, napts);
   free_vector (hy, 1, napts);
   free_vector (hphs, 1, napts);
   free_vector (detx, 1, Npixels);
   free_vector (dety, 1, Npixels);
   free_vector (detI, 1, Npixels);
   free_matrix (psfimg, 1, det_size, 1, det_size);

   return (0);
}
