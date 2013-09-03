/* bcv.c 	scw:7-16-99 : update: 6-11-02  		*/

/* These routines are for converting to/from surface figure errors and
 * compensating axial actuator forces. The matrices have been calculated
 * using the results of the BCV finite element analysis: "Mirror 6.5m
 * F/1.25: Axial Supports Influence Functions," Rep. #8 Rev. 0, Milano, Jan
 * 1995.  The data from this report are kept in
 * /net/abell/d1/hill/lb/MMT_BCV/.  Three MCAD worksheets have been used to
 * calculate and test the appropriate matrices from this data:
 * BCV_influenceTel.mcd, BCV_linked list.mcd, and Forc_corr.mcd.  The
 * matrices here are copied from the output of these worksheets. */

/* NOTE 8-9-99: the output from the above mathcad files is for the case of
 * figure testing from the radius of curvature (using Surf2ActRv_104.bin).
 * This needs to be redone for the prime focus geometry, and those matrices
 * used here.  NOTE2: the BCV conversion matrices are stored and read as
 * binary files.*/

/* NOTE 10-19-99: bcv.c now reads binary matrices for the prime focus (i.e.
 * telescope) geometry.  Two versions are available: Surf2ActTEL_104.bin
 * for a solution using all SVD modes, and Surf2ActTEL_32.bin for a
 * solution using only the lowest 32 modes for high frequency filtering
 * purposes */

/* NOTE: 9-19-00: Put in hooks for phasing the output zernikes to the
 * mirror for the orientation of the ihwfs mounted on the top box.  No
 * matter which Zernike checkbuttons are active, set tilt, defocus, and
 * coma to zero prior to calcing the bending forces.  */

/* 9-24-00: provided support for 4-theta and hi order trefoil.  Worked more
 * on phasing for force calcs.  Now is turnkey up to an including Z16 */

/* 10-27-00: added support for 5th order coma and 6th order spherical */

/* 5-30-01: had to remove sign changes on 5th order coma put in on 10-27-00
 * as the force mode file on hacksaw had reversed signs for both the X and
 * Y components! */

/* 1-10-02: moved BCV binary files from c_devel to current directory */

/* 6-11-02: started poly term corrections for f/9 shack-hartmann device */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "zernike.h"
#include "fileio.h"
#include "nrutil.h"

#define MAIN
#include "optics.h"


/* call main with a zernike polynomial file (*.zrn) and a poly string.
 * This routine will sample the zernikes at the BCV node points, then
 * perform a matrix multiply with [Surf2Act] to get the axial actuator
 * forces.  Alternatively, one can send the actuator forces, multiply by
 * [Act2Surf] and come up with the surface displacements. NOTE: This
 * routine works only with pure Zernike modes because they are easily
 * sampled at the BCV node points.  Raw phases (or residual phases after
 * mode subtraction) use a different routine that can spline the
 * Hartmann phase data onto the BCV node points.*/

/* pass:  argv[1] = .zrn or .zph file, argv[2] = poly string mask */

main (int argc, char *argv[])
{
  const int RPUP = 100;	/* resolution elements along XPM pupil radius */
  const int blur = 1;			/* widen each phase pixel by +/- blur */
  const int ACT = 104;	/* # MMT axial actuators */
  const int NODE = 3222;	/* # BCV nodes on mirror surface */
  const float BRAD= 3228.5;	/* BCV mirror radius (mm) */

  FILE *fp;
  float **nodes,		/* BCV node coordinates ID,x,y,z */
    **xy,			/* just the xy values of the BCV nodes */
    **Surf2Act,		/* convert surface displacement vector to actuator 
							force vector */
    **Act2Surf,		/* act forces to surf displacements */
    *zpoly,			/* Zernike poly coeff vector */
    *bcv_ph,		/* zernike phases (nm) at the BCV node points */
    *act_forc,		/* correcting force distibution (N) */
    **ph_tst,
    *disp,			/* surface displacement vecctor at bcv nodes */
    **actimg, **actxy, hold, gain;

  int i, j, k, y, z, I, J,
    *vmask;

  char *mask = argv[2];
  char *tmp, c[2] = {5,0};	/* atoi needs a string so trick it */
  char *wfsroot, *filename;

  gain = atof(argv[3]);

  vmask = ivector (1, ZPOLY);
  /* convert the string mask to an integer vector mask */
  tmp = mask;
  for (i=1;i<=ZPOLY;i++)
    {
      c[0] = *tmp++;
      vmask[i] = atoi(c);	/* atoi needs a string! */
    }

  zpoly = vector (1, ZPOLY);
  readVector (argv[1], zpoly, ZPOLY);	/* read poly coeffs */

  /* force the tilt, defocus, and coma coefficients to zero in the
   * createPhase() calc. --coma, defocus are corrected with M2 */

  vmask[1] = vmask[2] = 0;
  vmask[6] = vmask[7] = 0; /* set coma to zero */

  if (vmask[9] == 1) {
    vmask[10] = 1;
  }

  if (vmask[10] == 1) {
    vmask[9] = 1;
  }

  /* Now make adjustments to zpoly before finding forces.  Pass astig and
   * quad astig directly. The trefoil coefficents should be reversed as
   * well as the signs.*/

  zpoly[8] *= -1;		/* chs of spherical coeff for forces */

  /* turn down gain on a few terms */
     zpoly[4] *= gain; 
     zpoly[5] *= gain; 
     zpoly[8] *= gain;
     zpoly[9] *= gain;
     zpoly[10] *= gain;
     zpoly[11] *= gain;
     zpoly[12] *= gain;
     zpoly[13] *= gain;
     zpoly[14] *= gain;
     zpoly[15] *= gain;
     zpoly[16] *= gain;
     zpoly[17] *= gain;
     zpoly[18] *= gain;
     zpoly[19] *= gain;

  /* bmcleod found empirically that adding defocus at a level of 6 times
     the amount of spherical reduced the amount of force needed to 
     correct the spherical by about a factor of two. the GUI will take this
     defocus into account and adjust the secondary accordingly. this is 
     qualitatively similar to the "cone" bending mode of the primary that
     Magellan uses in their system to correct spherical.  

     TEP 5-18-2003
  */
  if (vmask[8] == 1) {
    vmask[3] = 1;
    zpoly[3] = -6.0*zpoly[8];
  }

  hold = zpoly[9];  /* save TrX coeff */
  zpoly[9] = zpoly[10];  /* place TrY into the TrX slot for forces */
  zpoly[10] = -hold;		/* place -TrX into the TrY slot */

  hold = zpoly[15];	/* save HiTrX coeff */
  zpoly[15] = zpoly[16]; /* place -HiTrY into the HiTrX slot for forces */
  zpoly[16] = -hold;	/* place HiTrX into the HiTrY slot for forces */
  
  zpoly[13] *= -1;	/* both 4-theta terms */
  zpoly[14] *= -1;

  zpoly[17] *= 1;		/* leave both 5th order coma terms alone */
  zpoly[18] *= 1;

  zpoly[19] *= -1;	/* chs on 6th order spherical */
	

  Surf2Act = matrix (1, ACT, 1, NODE);
  /*readMatrix ("Surf2Act", Surf2Act, ACT, NODE); */
  /* read in this large matrix as a binary file */
  if (getenv("WFSROOT")) {
    wfsroot = getenv("WFSROOT");
    filename = (char *) malloc(strlen(wfsroot) + 20); 
    strcpy(filename, wfsroot);
    strcat(filename, "/Surf2ActTEL_32.bin");
  } else {
    filename = "/mmt/shwfs/Surf2ActTEL_32.bin";
  }
  fp = fopen (filename, "r");
  fread (&Surf2Act[1][1], NODE*ACT,sizeof (float), fp);
  fclose (fp);
  free(filename);

  /* read BCV node coords (mm), first column is BCV ID#, then xyz. */
  nodes = matrix (1, NODE, 1, 4);
  xy = matrix (1, NODE, 1, 2);
  bcv_ph = vector (1, NODE);

  if (getenv("WFSROOT")) {
    wfsroot = getenv("WFSROOT");
    filename = (char *) malloc(strlen(wfsroot) + 10); 
    strcpy(filename, wfsroot);
    strcat(filename, "/nodecoor");
  } else {
    filename = "/mmt/shwfs/nodecoor";
  }
  readMatrix (filename, nodes, NODE, 4);
  free(filename);

  /* convert xy nodes to dimensionless xy coords */

  for (i=1; i<=NODE; i++)
    {
      xy[i][1] = nodes[i][2]/BRAD;
      xy[i][2] = nodes[i][3]/BRAD;
    }

  /* Sample the zpoly vector at each bcv node, and produce a surface error
   * vector that has the BCV node ordering. */
	
  act_forc = vector (1, ACT);
  createPhaseVector (zpoly, xy, NODE, bcv_ph, vmask); 

  /* convert wavefront to surface phases */
  for (i=1;i<=NODE;i++)
    bcv_ph[i] /= 2;

  writeVector("error.ph",bcv_ph,NODE); /* save 3222 vector */
  /*--------------------------------------------------------------*/
  /* for a previous test, read a Martin phase file and convert--test 
   * ph_tst = matrix (1, NODE, 1, 3); 
   * readMatrix ("/home/swest/ihwfs/1510hcor.nodes.xyz", ph_tst, NODE, 3);  
   * for (i=1;i<=NODE;i++)
   * bcv_ph[i] = ph_tst[i][3];  */
  /*--------------------------------------------------------------*/

  /* Calculate the axial actuator forces that remove the zernike
   * distortions. The vector of phase errors (nm) at the bcv node points
   * is multiplied by the Surf2Act matrix to return 104 axial forces (N)
   * that remove the surface error.  The vector is ordered as a stack of
   * two partitions: actuators 1-52 on top of actuators 101-152. */

  Mtv (Surf2Act, ACT, NODE, bcv_ph, act_forc);

  /* pass the axial forces back to ihwfs.tcl through the pipe */
  for (i=1;i<=ACT;i++)
    printf ("%5.1f ", act_forc[i]);

  /* write an XPM driver to display a colored scatterplot diagram of the
   * the actuator force distribution at the entrance aperture. Modelled
   * after the pup_discretePhs driver. */
  if (getenv("WFSROOT")) {
    wfsroot = getenv("WFSROOT");
    filename = (char *) malloc(strlen(wfsroot) + 16); 
    strcpy(filename, wfsroot);
    strcat(filename, "/actcoordsmm.dat");
  } else {
    filename = "/mmt/shwfs/actcoordsmm.dat";
  }
  actxy = matrix (1, 104, 1, 4);	/* actuator coords in mm. ID, x,y, type */
  readMatrix (filename, actxy, ACT, 4);
  free(filename);
  /* convert to dimensionless coords */
  for (i=1;i<=ACT;i++)
    {
      actxy[i][2] /= BRAD;
      actxy[i][3] /= BRAD;
    }

  actimg = matrix (1,2*RPUP,1,2*RPUP);

  /* make the initial XPM grid, and set all pixels to transparent */
  for (i=-RPUP;i<RPUP;i++)
    for (j=-RPUP;j<RPUP;j++)
      actimg[i+RPUP+1][j+RPUP+1] = -100000;

  /* map xy coords onto image by writing over pixels */
  for (k=1;k<=ACT;k++)
    {
      /* make coords 5% smaller than image (for blurring at boundaries). */
      I = actxy[k][2] * (float)RPUP * .95;
      J = actxy[k][3] * (float)RPUP * .95;

      /* blur each point */
      for (y=-blur; y<=blur;y++)
	{
	  i = I + y;
	  for (z=-blur; z<=blur;z++)
	    {
	      j = J + z;
	      actimg[i+RPUP+1][j+RPUP+1] = act_forc[k];
	    }
	}
    }

  makeXPM (actimg, 2*RPUP, 2*RPUP, 0, 100, 1, "actforce.xpm");


  free_vector (zpoly, 1, ZPOLY);
  free_ivector (vmask, 1, ZPOLY);
  free_matrix (Surf2Act, 1, ACT, 1, NODE);
  free_matrix (nodes, 1, NODE, 1, 4);
  free_matrix (xy, 1, NODE, 1, 2);
  free_vector (bcv_ph, 1, NODE);
  free_vector (act_forc, 1, ACT);
  /* free_matrix (ph_tst, 1, NODE, 1, 3); */
  free_matrix (actxy, 1, 104, 1, 4);

  return (0);
}

