/* getZernikesAndPhases.c ; scw 7-1-99: update: 7-29-99 */

/* This routine receives two centroid file names -- a system and stellar
 * file passed in that order. It first associates the spots within each
 * file, calculates the pupil coordinates, and then finds both the wavefront
 * gradients and phase differences. The routine then proceeds to solve for
 * the Zernike polynomial coefficients from the wavefront gradients and
 * [optionally] from the pupil phase differences.  The phase calc determines
 * both the raw phases in each Hartmann aperture and the zernike
 * coefficients from that phase distribution. */

/* NOTE: The phase solve has inherently higher resolution even though the
 * number of pupil sampling points is only slightly larger than the
 * gradient solve.  This is because the gradients represent averages of the
 * surrounding 4 phase apertures while the phase data are reduced to phases
 * at the location of the hartmann aperture. The latter procedure involves
 * the inversion of a substantially larger matrix and requires a
 * significant amount of computation time to perform the SVD. */
  
/* The phase solve calculates raw phases regardless of whether they fit
 * zernike modes or not.  Whereas the gradient solve fits only slopes
 * corresponding to zernikes and throws the remainder out. */
 
/* NOTE2: This routine is capable of making 3 kinds of output files.  The
 * first has a .zrn extension and contains ZPOLY zernike coefficients that
 * result from the low resolution gradient calculation.  The other two
 * types result from the [optional] phase calculation.  ".zph" are the
 * ZPOLY zernike coefficients determined from the raw phases.  ".phs" is a
 * 3-column file that contains the dimensionless xy coords of each aperture
 * and the phase (nm) contained at each location. */

/* 4-18-02: changed this version to simply output the unscaled tot_tilt
 * vector and quit (for Shack Hartmann testing) */

/* 4-23-02: added changes so this routine provides a complete replacement
 * for getShackZernikes.c.  It now runs just like the old ihwfs in gradient
 * solve mode. */

/* 4-23-02: changed tot_tilt calc to use a straight scale factor rather
 * than nm/pix and ap_sp that ihwfs used */

/* 6-2-02: added rotation angle calculations.    Flow is: calc linked list,
 * rotate, then use unrotated linked list to access the coords. The only
 * centroid files kept on disk are unrotated.  This routine rotates both
 * the stellar and system centroids internally, but does not save the
 * rotated results. Another parameter will have to be added to the stellar
 * file which contains the rotation angle (home offset + parallactic). */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "zernike.h"
#include "WFSlib.h"
#include "fileio.h"
#define MAIN
#include "optics.h"
#include "nrutil.h"

/* call main with (system.cntr, stellar.cntr,  0 or 1, rot_angle)  where
 * argv[3] = 0 means don't solve for phases and 1 means solve for phases.
 * This is optional because the phase solve involves a very large matrix
 * SVD. argv[4] contains the angle to rotate (degrees, + = CW) the centroids
 * prior to calculating the zernikes.
 */

main(int argc, char *argv[])
{

  float **stel, **sys,	     /* pointers to corrected centroid files */
    **stel_org, **sys_org,   /* pointers to original centroid files */
    **stel_rot, **sys_rot,   /* pointers to rotated centroid files */
    xm1, ym1, xo1, yo1, xm2, ym2, xo2, yo2,	/* mags and offsets */
    xr1, yr1, xr2, yr2,	     /* rotated offsets */
    sys_mag, stel_mag, mag,
    rot,		     /* angle to rotate centroids (degrees +=CW */
    xtmp, ytmp,		     /* temp storage for rot calc */
    **link,		     /* linked list array */
    *tot_tilt, 		     /* stacked partition wavefront gradient vector */
    **dpc,		     /* dimensionless pupil coords of system spots */
    **AG,		     /* Gradient SVD matrix for finding Zerns */
    *xZ,		     /* Zernike coeff. vector */
    *wG,		     /* diagonal SVD vector for AG */
    **VG,		     /* SVD V-matrix for AG */
    **sys_dim, **stel_dim,
    **ph_out;		     /* x,y, phase matrix output to file.phs */

  int st_nr, st_nc, sys_nr, sys_nc,
    i, j,
    l;		/* holds the size of the link array retruned from WFSlib */
	
  char *fout;		/* file output name */

  fout = (char *) malloc(strlen(argv[2]) + 5);

  if (argc < 5) return (0); /* too few parameters passed */

  printf ("Getting first file %s.\n", argv[1]);
  fflush (stdout);
  /* get the data from the files */
  fileDim(argv[1], &sys_nr, &sys_nc);
  sys = matrix (1, sys_nr, 1, sys_nc);
  sys_org = matrix (1, sys_nr, 1, sys_nc);
  sys_rot = matrix (1, sys_nr, 1, sys_nc);
  readMatrix (argv[1], sys, sys_nr, sys_nc);
  readMatrix (argv[1], sys_org, sys_nr, sys_nc);
  getMagOffsets(argv[1], &xm1, &ym1, &xo1, &yo1);
  sys_mag = (xm1 + ym1)/2;		/* average lateral magnifications */
  printf ("sys mag = %f\n", sys_mag);

  fileDim(argv[2], &st_nr, &st_nc);
  stel = matrix (1, st_nr, 1, st_nc);
  stel_org = matrix (1, st_nr, 1, st_nc);
  stel_rot = matrix (1, st_nr, 1, st_nc);
  readMatrix (argv[2], stel, st_nr, st_nc);
  readMatrix (argv[2], stel_org, st_nr, st_nc);
  getMagOffsets(argv[2], &xm2, &ym2, &xo2, &yo2);
  stel_mag = (xm2 + ym2)/2;
  printf ("stel mag = %f\n", stel_mag);

  printf ("Finished second file %s.\n", argv[2]);

  rot = atof (argv[4])/57.295780; /* store rotation angle in degrees */
  printf ("rotation angle is %5.1f degrees.\n", rot*57.29578);

  /* Apply offsets and center each interferogram on the origin. For now,
   * the magnification is removed from the fit, and therefore the defocus
   * term relative to the system interferogram should be zero -- Change
   * this later.  Note also that for now, the magnification in both
   * lateral directions are assumed equal */

  /* Apply offset only to system interferogram */

  for (i = 1; i<= sys_nr; i++) {  
    sys[i][1] -= xo1; sys[i][2] -= yo1; 
  }

  /* apply offsets AND magnification to the stellar interferogram -- note
   * that this means that defocus is measured relative to the system
   * interferogram */

  mag = sys_mag/stel_mag; /* differential magnification */

  for (i = 1; i<=st_nr; i++) { 
    stel[i][1] = (stel[i][1] - xo2) * mag;
    stel[i][2] = (stel[i][2] - yo2) * mag;
  }

  writeMatrix ("stest1.cntr", sys, sys_nr, sys_nc);
  writeMatrix ("stest2.cntr", stel, st_nr, st_nc);
	
  /* Now that the two interferograms have nearly equal magnifications and are
   * centered on the origin, find the spots that are likely to be formed by
   * the same phase apertures in the Hartmann mask, and save the link file.
   * associateSpots() also returns the size of the linked list 'l'. */

	
  link = matrix(1,sys_nr,1,2); /* set link to the size of the system
				  interf */

  associateSpots(link, &l, sys, sys_nr, stel, st_nr); 
  printf ("finished associateSpots\n");

  writeMatrix ("link", link, l, 2);

  sys_dim = matrix(1,l,1,2);	/* hold the dimensionless centered and
				   associated spot information for debugging */

  stel_dim = matrix(1,l,1,2);

  for (i=1;i<=l;i++) {
    sys_dim[i][1] = sys[(int)link[i][1]][1];
    sys_dim[i][2] = sys[(int)link[i][1]][2];

    stel_dim[i][1] = stel[(int)link[i][2]][1];
    stel_dim[i][2] = stel[(int)link[i][2]][2];
  }

  /* write linked spots to files */
  writeMatrix ("sys_dim.cntr", sys_dim, l, 2);
  writeMatrix ("stel_dim.cntr", stel_dim, l, 2);

  /* rotate both the original stellar and system centroid files-- rotate all
   * points.  Only the linked ones will be obtained below. */

  /* rotate stellar center about the system center to obtain the rotated
   * offsets  */

  xtmp = xo2 - xo1; ytmp = yo2 - yo1;

  xr2 = xtmp * cos(rot) + ytmp * sin(rot);
  yr2 = ytmp * cos(rot) - xtmp * sin(rot);

  printf ("xtmp = %5.3f, ytmp = %5.3f\n", xtmp, ytmp);
  printf ("xr2 = %5.3f, yr2 = %5.3f\n", xr2, yr2);
	
  /* rotate original stellar pattern */
  for (i=1;i<=st_nr;i++) {
    
    /* translate unrotated coord to origin */
    xtmp = stel_org[i][1] - xo2 ; ytmp = stel_org[i][2] - yo2;

    /* rotate */
    stel_rot[i][1] = xtmp * cos (rot) + ytmp * sin (rot);
    stel_rot[i][2] = ytmp * cos (rot) - xtmp * sin (rot);

    /* restore rotated offsets to preserve tilts in solve */
    /* stel_rot[i][1] += xo2; stel_rot[i][2] += yo2; */ 
    /* restore rotated offsets */
    stel_rot[i][1] += xo1 + xr2 ; stel_rot[i][2] += yo1 + yr2;  

  }
		
  /* rotate original system pattern */
  for (i=1;i<=sys_nr;i++) {

    /* translate unrotated coord to origin */
    xtmp = sys_org[i][1] - xo1 ; ytmp = sys_org[i][2] - yo1;

    /* rotate */
    sys_rot[i][1] = xtmp * cos (rot) + ytmp * sin (rot);
    sys_rot[i][2] = ytmp * cos (rot) - xtmp * sin (rot);

    /* restore offsets to preserve tilts in solve */
    sys_rot[i][1] += xo1 ; sys_rot[i][2] += yo1;
  }
		
  /* rotate previously offset system pattern for dpc calc */
  for (i=1;i<=sys_nr;i++) {

    /* translate unrotated coord to origin */
    xtmp = sys[i][1] ; ytmp = sys[i][2];

    /* rotate */
    sys[i][1] = xtmp * cos (rot) + ytmp * sin (rot);
    sys[i][2] = ytmp * cos (rot) - xtmp * sin (rot);

    /* do not restore offsets since dpc must be at origin */

  }

  /* Now, link contains the indices of the spots that correspond in the two
   * files (col 1 is the system index, and col 2 is the stellar index).  We
   * can now solve for the wavefront gradient and phase differences between
   * those spots. These indices can be used to reference the centroids of the
   * original data.  This differs from the MathCad formulation in that
   * calculation removes the magnification and offset terms (which are just
   * defocus and tilt terms).  Including them here yields a more complete and
   * realistic solution */

  dpc = matrix (1,l,1,2);
  AG = matrix (1, 2*l, 1, ZPOLY);
  wG = vector (1, ZPOLY);
  VG = matrix (1, ZPOLY, 1, ZPOLY);
  tot_tilt = vector (1, 2*l); /* stacked partition tilt vector (b) */
  xZ = vector (1, ZPOLY);     /* solved Zernike coefficients (x)*/
  printf ("finished mallocing \n");

  printf ("pix/pup is %5.3f\n", pix_pup);

  for (i=1;i <= l; i++) {
    /* x-partition gradient vector USING ORIGINAL DATA */
    tot_tilt[i] = -TILTFACTOR*(stel_rot[(int)link[i][2]][1] - 
			       sys_rot[(int)link[i][1]][1]) ;
    /* y-partition gradient vector USING ORIGINAL DATA */
    tot_tilt[i+l] = -TILTFACTOR*(stel_rot[(int)link[i][2]][2] - 
				   sys_rot[(int)link[i][1]][2]) ;

    /* Calc the dimensionless pupil coords for each linked spot. Don't
     * change the dpc arrays -- they need the offsets applied. Also,
     * they are calculated from the positions of the system spots which
     * may not be scaled correctly to the pupil if the instrument is not
     * set up carefully -- need to clean this up later. */

    dpc[i][1] = sys[(int)link[i][1]][1] / (pix_pup/2); 
    dpc[i][2] = sys[(int)link[i][1]][2] / (pix_pup/2); 
  }
				
  writeMatrix ("dpcraw", dpc, l, 2);
  writeVector ("tot_tilt", tot_tilt, 2*l);

  /* Calculate the Gradient matrix [AG] in [A](x) = (b) using the
   * dimensionless pupil coords. I call it [AG] to differentiate it from
   * [AP] which is the phase difference matrix. */

  printf ("starting createGradient...\n");

  /* dummy coords to check matrix calc */

  createGradientMatrix (AG, dpc, l);

  writeMatrix ("AG", AG, 2*l, ZPOLY);  

  /* call to SVD passes ([A],Arows, Acols, (w), [V]) After returning, [A] 
   * becomes [U] and w and V are filled. */

  svdcmp(AG, 2*l, ZPOLY, wG, VG);

  /* set small wi's to zero per SVD rules -- svbksb() knows how to deal
   * with 0 elements */

  for (i=1;i<=ZPOLY;i++)
    if (wG[i] <= 0.01) wG[i]=0;	
		
  svbksb (AG, wG, VG, 2*l, ZPOLY, tot_tilt, xZ);  

  /* choose file output name, and write polynomial coefficients */
	
  sprintf (fout,"%s.zrn", argv[2]);

  writeVector (fout, xZ, ZPOLY);

  /* Now perform the phase difference solution if argv[3] = 1.  Instead of
   * wavefront gradients being calculated as above, phase shifts are
   * calculated.  The matrix [AP] (for A phase) multiplies the phases (p) from
   * the individual hartman apertures to obtain the phase difference vector
   * (pd) -- [AP](p) = (pd).  After inversion with SVD, [AP]^-1 times the
   * phase diff vector yields the individual Hartmann phases.  Another SVD
   * operation fits Zernike polynomials to the phase distribution. NOTE: This
   * routine has it's own declarations that are invisible to the routine
   * above, however the above stuff is visible to this routine. */

  if (atoi (argv[3]) == 1) {

    const float dap = ap_sp/2;  /* dim'less pupil half spacing between aps */
    const float ptol = ap_sp/4; /* overlap tolerance of apertures */

    float **AP,	/* phase difference partition matrix */
      *wP,		/* diagonal vector required by SVD */
      **VP,		/* other SVD matrix */
      *xZp,		/* hold zernike coeffs from phase solve */
      *xP,		/* hartmann phase vector */
      **apts,		/* array of apertures in dim pupil coords */
      **aplinks,	/* array whose index is the spot ID (index of link[][])
			   and whose 4 values give the IDs of the apertures in
			   apts. */
      spotx, spoty,	/* current sys spot coords */
      *pdiff,		/* full partition phase difference vector */
      **AZ2P, *wZ2P, **VZ2P,	/* SVD phases in apts to zernike solve */
      **rth;
	
    int apcnt,	/* aperture counter */
      exist[5], 	/* check for aperture existence (use only 1-4) */
      i, j, z,	/* general counters */
      lapt;		/* # apertures synthesized */

    printf ("I'm here.../n");
    aplinks = matrix (1, l, 1, 4);
    apts = matrix (1, 2*l, 1, 2);	/* xy coords of synthesized apertures--
					   currently set to 2l, but apcnt 
					   will have final size */
    pdiff = vector (1, 2*l);
						
    /* synthesize positions of the hartmann masks in dimensionless coords.
     * The mask positions are referenced to the system spot positions */

    /* set up the first set of apertures around the first system spot. NOTE
     * the use of dpc[][] rather than sys or sys_org--dpc is in centered
     * dimensionless coords and it is sorted by link already. */

    spotx = dpc[1][1];
    spoty = dpc[1][2];

    apts[1][1] = spotx - dap; apts[1][2] = spoty + dap;
    apts[2][1] = spotx - dap; apts[2][2] = spoty - dap;
    apts[3][1] = spotx + dap; apts[3][2] = spoty + dap;
    apts[4][1] = spotx + dap; apts[4][2] = spoty - dap;

    apcnt = 5;

    aplinks[1][1] = 1; aplinks[1][2] = 2; 
    aplinks[1][3] = 3; aplinks[1][4] = 4;

    for (i=2; i <= l; i++) {	/*loop through rest of sys spots */
      exist[1] = exist[2] = exist[3] = exist[4] = -1; /* set no exist */

      spotx = dpc[i][1];
      spoty = dpc[i][2];

      for (j=1; j <=apcnt-1; j++) {	/* loop through existing apertures */

	if ( (fabs(apts[j][1] - (spotx - dap)) < ptol) && 
	     (fabs(apts[j][2] - (spoty + dap)) < ptol)) 
	  {exist[1] = j;}
			
	if ( fabs(apts[j][1] - (spotx - dap)) < ptol && 
	     fabs(apts[j][2] - (spoty - dap)) < ptol) 
	  {exist[2] = j;}
		
	if ( fabs(apts[j][1] - (spotx + dap)) < ptol && 
	     fabs(apts[j][2] - (spoty + dap)) < ptol) 
	  {exist[3] = j;} 

	if ( fabs(apts[j][1] - (spotx + dap)) < ptol && 
	     fabs(apts[j][2] - (spoty - dap)) < ptol) 
	  {exist[4] = j;}
      }
	  
      for (z=1; z <=4; z++) {	/* create new apertures for spot if needed */
	if (exist[z] == -1) {	/* create new aperture */
	  apts[apcnt][1] = (z==1 || z==2) ? spotx-dap : spotx + dap;
	  apts[apcnt][2] = (z==4 || z==2) ? spoty-dap : spoty + dap;
	  aplinks[i][z] = apcnt++;
	}

	/* assign existing aperture -- don't increment apcnt! */
	if (exist[z] != -1) aplinks[i][z] = exist[z];	
      }

    }

    lapt = apcnt - 1;	/* set # of apertures created */


    writeMatrix ("apts.cntr", apts, lapt, 2);
    writeMatrix ("aplinks", aplinks, l, 4);

    /* Calculate the x and y phase differences between the two
     * interferograms. This is the phase difference vector (b) in the first
     * SVD below that finds the Hartmann phases. */

    for (i=1; i<=l; i++) {	/* just scale the tilts */
      pdiff[i] = tot_tilt[i] * 2 * ap_sp;	/* x-partition */
      pdiff[i+l] = tot_tilt[i+l] * 2 * ap_sp; /* y-partition */
    }

    /* Now that the aperture positions have been synthesized and linked 
       to the system spots, do the SVD */

    AP = matrix(1, 2*l, 1, lapt); /* converts phases vect to pdiff vector */
    wP = vector (1, lapt);
    VP = matrix (1, lapt, 1, lapt);
    xP = vector (1, lapt);	/* hartmann phases (x) */

    for (i=1;i<=l;i++) {		/* create phase to pdiff matrix */
      /* x-partition */
      AP[i][(int)aplinks[i][1]] = -1;
      AP[i][(int)aplinks[i][2]] = -1;
      AP[i][(int)aplinks[i][3]] = 1;
      AP[i][(int)aplinks[i][4]] = 1;

      /* y-partition */
      AP[i+l][(int)aplinks[i][1]] = 1;
      AP[i+l][(int)aplinks[i][2]] = -1;
      AP[i+l][(int)aplinks[i][3]] = 1;
      AP[i+l][(int)aplinks[i][4]] = -1;
    }

    printf ("Starting phase svdcmp...\n");
    /* decompose AP into [U], (w), and [V] */
    svdcmp (AP, 2*l, lapt, wP, VP);

    /* set small wi's to zero per SVD rules -- svbksb() knows how to deal
     * with 0 elements */

    for (i=1;i<=lapt;i++)
      if (wP[i] <= 0.01) wP[i]=0;	
		
    printf ("Starting back solve...\n");
    /* Now solve for the hartmann phases (nm) */
    svbksb (AP, wP, VP, 2*l, lapt, pdiff, xP);  
    printf ("Finished back solve\n");

    /* combine the aperture coordinates with the phases and 
       output to file*/

    ph_out = matrix (1, lapt, 1, 3);
    for (i=1;i<=lapt;i++) {
      ph_out[i][1] = apts[i][1];
      ph_out[i][2] = apts[i][2];
      ph_out[i][3] = xP[i];
    }
		
    sprintf (fout,"%s.phs", argv[2]);
    writeMatrix (fout, ph_out, lapt, 3);

    /* Now solve for the Zernike coefficients from the phase data */

    xZp = vector (1, ZPOLY);	/* zernike coeff vector */	

    /* matrix that converts zernike coefficients to aperture phases */
    AZ2P = matrix (1, lapt, 1, ZPOLY);
	
    wZ2P = vector (1, ZPOLY);
    VZ2P = matrix (1, ZPOLY, 1, ZPOLY);
    rth = matrix (1, lapt, 1,2);	/* r, theta hartmann apt xcoords */
		
    /* convert xy apt pairs to r, theta */			
    /* removed since xy monomials are used now 8-17-00*/
    /*	for (i=1; i<=lapt; i++)
	{
	rth[i][1] = sqrt ( apts[i][1]*apts[i][1] + apts[i][2]*apts[i][2]);
	rth[i][2] = atan2 (apts[i][2],apts[i][1]);
	}
    */

    /* this call used to use **rth instead of **apts -- 8-17-00 */
    createPhaseMatrix (AZ2P, apts, lapt); /*evaluate zernikes at apt coords */

    svdcmp (AZ2P, lapt, ZPOLY, wZ2P, VZ2P);
				
    /* set small wi's to zero per SVD rules -- svbksb() knows how to deal
     * with 0 elements */

    for (i=1;i<=ZPOLY;i++)
      if (wZ2P[i] <= 0.01) wZ2P[i]=0;	

    svbksb (AZ2P, wZ2P, VZ2P, lapt, ZPOLY, xP, xZp);

    sprintf (fout,"%s.zph", argv[2]);
    
    writeVector (fout, xZp, ZPOLY);
      
    free_matrix (aplinks, 1, l, 1, 4);
    free_matrix (apts, 1, 2*l, 1, 2);
    free_vector (pdiff,1, 2*l);
    free_matrix (AP, 1, 2*l, 1, lapt);
    free_matrix (VP, 1, lapt, 1, lapt);
    free_vector (wP, 1, lapt);
    free_vector (xP, 1, lapt);
    free_vector (xZp, 1, ZPOLY);
    free_matrix (AZ2P, 1, lapt, 1, ZPOLY);
    free_vector (wZ2P, 1, ZPOLY);
    free_matrix (VZ2P, 1, ZPOLY, 1, ZPOLY);
    free_matrix (rth, 1, lapt, 1, 2);
    free_matrix (ph_out, 1, lapt, 1, 3);

  }

  free_matrix (stel, 1, st_nr, 1, st_nc);
  free_matrix (stel_org, 1, st_nr, 1, st_nc);
  free_matrix (stel_rot, 1, st_nr, 1, st_nc);
  free_matrix (sys, 1, sys_nr, 1, sys_nc);
  free_matrix (sys_org, 1, sys_nr, 1, sys_nc);
  free_matrix (sys_rot, 1, sys_nr, 1, sys_nc);
  free_matrix (link, 1, sys_nr, 1, 2);
  free_matrix (dpc, 1,l,1,2);
  free_vector (wG, 1, ZPOLY);
  free_matrix (AG, 1, 2*l, 1, ZPOLY);
  free_matrix (VG, 1, ZPOLY, 1, ZPOLY);
  free_vector (tot_tilt, 1, 2*l);
  free_vector (xZ, 1, ZPOLY);
  
  free_matrix (sys_dim, 1, l, 1, 2);
  free_matrix (stel_dim, 1, l, 1, 2);

  return (0);

}

/* THE END */
