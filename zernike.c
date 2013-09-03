/* zernike.c is a depository for zernike polynomials and their derivatives.
 * There are two types of zernike terms: 1) those for an unobstructed
 * circular pupil which we'll call uZ for "simple" zernike, and 2) those for
 * a centrally obstructed circular pupil cZ.  Their derivatives are duZ/dx,
 * duZ/dy, dcZ/dx, and dcZ/dy. scw: 4-15-99; update 8-17-00 */

 /* NOTE: this convention has theta=0 along the y-axis!  It also appears
  * that theta increases towards the x-axis (clockwise). Adopted from Optical
  * Shop Testing II (why can't they leave well enough alone?). So now,
  * x=rsinth and y=rcosth. */

 #include <stdio.h>
 #include <stdlib.h>
 #include <math.h>
 #include "nrutil.h"
 #include "zernike.h"

 /* uZ() returns  the value of the UNITY unobstructed polynomial n given the
  * dimensionless r and theta (th). Tested with Mathcad's phasediff stuff
  * and verified. The calling routine must multiply the output by the
  * appropriate zernike coefficient.  */

float upolarZ(int n, float r, float th) {
 	
  switch (n) {

  case 1: return (r*sin(th));		/* tilt about y-axis */

  case 2: return (r*cos(th));		/* tilt about x-axis */

  case 3: return (2*pow(r,2)-1);	/* defocus */

  case 4: return (pow(r,2)*sin(2*th));	/* astig +/- 45 deg axis */ 

  case 5: return (pow(r,2)*cos(2*th));	/* astig axis at 0 or 90 */

  case 6: return ((3*pow(r,3) - 2*r) * sin(th)); /* coma along x-axis */

  case 7: return ((3*pow(r,3) - 2*r) * cos(th)); /* coma along y-axis */

  case 8: return (6*pow(r,4) - 6*pow(r,2) + 1); /* 3rd spherical */

    /* trefoil with base on x-axis TRFx*/
  case 9: return (pow(r,3) * sin(3*th));

    /* trefoil with base on y-axis TRFy*/
  case 10: return (pow(r,3) * cos(3*th));

    /* ashtray astig */
  case 11: return ((4*pow(r,4) - 3*pow(r,2)) * sin(2*th));

  case 12: return ((4*pow(r,4) - 3*pow(r,2)) * cos(2*th));

  }
}

/* monomial zernike expansion */

float uZ(int n, float x, float y) {

  switch (n) {

  case 1: return (x);		/* tilt about y-axis */

  case 2: return (y);		/* tilt about x-axis */

  case 3: return (2*y*y + 2*x*x -1);	/* defocus */

  case 4: return (2*x*y);		/* astig at +/-45-deg */

  case 5: return (y*y - x*x);	/* astig at 0/90 deg */

  case 6: return (3*x*x*x + 3*x*y*y - 2*x);	/* coma along x */

  case 7: return (3*y*y*y + 3*y*x*x - 2*y);	/* coma along y */

    /* 3rd order spherical */
  case 8: return (1 - 6*y*y - 6*x*x + 6*y*y*y*y + 12*x*x*y*y + 6*x*x*x*x);

  case 9: return (3*x*y*y - x*x*x);	/* trefoil base on x-axis */

  case 10: return (y*y*y - 3*x*x*y);	/* trefoil base on y-axis */

  case 11: return (8*x*x*x*y + 8*y*y*y*x - 6*x*y); /* 5thast45 */	

  case 12: return (4*y*y*y*y - 4*x*x*x*x + 3*x*x - 3*y*y); /* 5thast0 */

  case 13: return (4*y*y*y*x - 4*x*x*x*y); /* 4th1 */

  case 14: return (y*y*y*y - 6*x*x*y*y + x*x*x*x); /* 4th2 */

  case 15: return (4*x*x*x - 12*x*y*y + 15*x*y*y*y*y + 10*x*x*x*y*y
		   - 5*x*x*x*x*x); /* hitrefX */

  case 16: return (12*x*x*y - 4*y*y*y + 5*y*y*y*y*y - 10*x*x*y*y*y
		   - 15*x*x*x*x*y); /* hitrefY */

  case 17: return (3*x - 12*x*y*y - 12*pow(x,3) + 10*x*pow(y,4)
		   + 20*pow(x,3)*y*y + 10*pow(x,5));	/* 5thCX */

  case 18: return (3*y - 12*y*y*y - 12*x*x*y + 10*pow(y,5)
		   + 20*x*x*pow(y,3) + 10*pow(x,4)*y); /* 5thCY */

  case 19: return (20*pow(x,6) + 20*pow(y,6) + 60*x*x*pow(y,4) 
		   + 60*pow(x,4)*y*y - 30*pow(x,4) - 30*pow(y,4) - 60*x*x*y*y
		   + 12*x*x + 12*y*y - 1); /* 6th order spherical */

  case 20: return (5*x*y*y*y*y - 10*x*x*x*y*y + x*x*x*x*x); /* 5th1 */

  case 21: return (y*y*y*y*y - 10*x*x*y*y*y +5*x*x*x*x*y); /* 5th2 */

  }
}

/* duZdx() and duZdy() return uZ terms differentiated by x and y for an
 * unobstructed circular pupil.  Both of these routines have been checked
 * with MathCad's phasediff stuff.  NOTE:  phasediff uses 0 origin while all
 * this NR stuff uses 1 origin. These coefficients have UNITY amplitude, and
 * the calling routine must scale them appropriately. */

/* monomial representation of the gradients for an unobstructed circular
 * pupil. */

float duZdx(int n, float x, float y) {

  switch (n) {

  case 1: return (1);			/* dTy/dx */

  case 2: return (0);			/* dTx/dx */
    
  case 3: return (4*x);		/* dD/dx */

  case 4: return (2*y);		/* dAst45/dx */

  case 5: return (-2*x);		/* dAst0/dx */

  case 6: return (9*pow(x,2) + 3*pow(y,2) - 2);	/* dCx/dx */

  case 7: return (6*x*y);		/* dCy/dx */

  case 8: return (24*pow(x,3) + 24*x*pow(y,2) -12*x);  /* dS3/dx */

  case 9: return ((3*pow(y,3) - 3*pow(x,2)));		/* dTRFx/dx */

  case 10: return (-6*x*y);	/* dTRFy/dx */

  case 11: return (8*pow(y,3) +24*pow(x,2)*y - 6*y);	/* d5ast45/dx */

  case 12: return (6*x - 16*pow(x,3));	/* d5ast0/dx */

  case 13: return (4*y*y*y - 12*x*x*y); /* d4th1/dx */

  case 14: return (4*x*x*x - 12*x*y*y); /* d4th2/dx */

  case 15: return (12*x*x - 12*y*y + 15*y*y*y*y + 30*x*x*y*y
		   - 25*x*x*x*x); /* dhiTrX/dx */

  case 16: return (24*x*y - 20*x*y*y*y - 60*x*x*x*y); /* dhiTrY/dx */

  case 17: return (3 - 12*y*y -36*x*x + 10*pow(y,4) + 60*x*x*y*y
		   + 50*pow(x,4)); 	/* d5thCX/dx */

  case 18: return (40*x*y*y*y - 24*x*y + 40*x*x*x*y); /* d5thCY/dx */

  case 19: return (120*pow(x,5) + 120*x*pow(y,4) + 240*x*x*x*y*y
		   - 120*x*x*x - 120*x*y*y + 24*x); /* dsph6/dx */

  case 20: return (5*y*y*y*y - 30*x*x*y*y + 5*x*x*x*x); /* d5th1/dx */

  case 21: return (20*x*x*x*y - 20*x*y*y*y);	/* d5th2/dx */

  }
}


float duZdy (int n, float x, float y) {
  switch (n) {

  case 1: return (0);			/* dTy/dy */

  case 2: return (1);			/* dTx/dy */

  case 3: return (4*y);		/* dD/dy */

  case 4: return (2*x);		/* dAst45/dy */

  case 5: return (2*y);		/* dAst0/dy */

  case 6: return (6*x*y);		/* dCx/dy */

  case 7: return (9*pow(y,2) + 3*pow(x,2) - 2);		/* dCy/dy */

  case 8: return (24*pow(y,3) + 24*pow(x,2)*y - 12*y); /* dS3/dy */

  case 9: return (6*x*y);		/*dTRFx/dy */

  case 10: return (3*pow(y,2) - 3*pow(x,2));		/* dTRFy/dy */

  case 11: return (8*pow(x,3) + 24*pow(y,2)*x - 6*x);	/* d5ast45/dy */

  case 12: return (16*pow(y,3) - 6*y); /* d5ast0/dy */

  case 13: return (12*y*y*x - 4*x*x*x); /* d4th1/dy */ 

  case 14: return (4*y*y*y - 12*x*x*y); /* d4th2/dy */

  case 15: return (60*x*y*y*y - 24*x*y + 20*x*x*x*y); /* dhiTrX/dy */

  case 16: return (12*x*x - 12*y*y + 25*y*y*y*y - 30*x*x*y*y
		   - 15*x*x*x*x); /* dhiTrY/dy */

  case 17: return (40*x*y*y*y - 24*x*y + 40*x*x*x*y); /* d5thCX/dy */

  case 18: return (3 - 36*y*y - 12*x*x + 50*pow(y,4) + 60*x*x*y*y
		   + 10*pow(x,4));	/* d5thCY/dy */

  case 19: return (120*pow(y,5) + 240*x*x*y*y*y + 120*pow(x,4)*y
		   - 120*y*y*y - 120*x*x*y + 24*y);	/* dsph6/dy */

  case 20: return (20*x*y*y*y - 20*x*x*x*y);	/* d5th1/dy */

  case 21: return (5*y*y*y*y - 30*x*x*y*y + 5*x*x*x*x); /* d5th2/dy */

  }
}

float duMCADZdx(int n, float x, float y) {

  float r,
    ATANyx;		/* atan (y/x) */

  ATANyx = atan (y/x);

  r = sqrt (pow(x,2) + pow(y,2));

  switch (n) {

  case 1: return (1);			/* dTx/dx */

  case 2: return (0);			/* dTy/dx */
    
  case 3: return (4*x); 		/* dD/dx */

    /* dAx/dx */
  case 4: return (2*x*cos(2*ATANyx) + 2*y*sin(2*ATANyx));

    /* dAy/dx */
  case 5: return (2*x*sin(2*ATANyx) - 2*y*cos(2*ATANyx));

  case 6: return (3*pow(y,2) + 9*pow(x,2) - 2);	/* dCx/dx */
    
  case 7: return (6*y*x);		/* dCy/dx */

  case 8: return (24*pow(x,3) + 24*x*pow(y,2) - 12*x);	/* dS3/dx */

    /* dTRx/dx */
  case 9: return (3*x*r*cos(3*ATANyx) + 3*y*r*sin(3*ATANyx));

    /* dTRy/dx */
  case 10: return (3*x*r*sin(3*ATANyx) - 3*y*r*cos(3*ATANyx));

    /* dAAx/dx */
  case 11: return (16*pow(x,3)*cos(2*ATANyx) +
		   8*y*pow(x,2)*sin(2*ATANyx) + 16*x*pow(y,2)*cos(2*ATANyx) -
		   6*x*cos(2*ATANyx) - 6*y*sin(2*ATANyx) + 
		   8*pow(y,3)*sin(2*ATANyx));

    /* dAAy/dx */
  case 12: return (16*pow(x,3)*sin(2*ATANyx) -
		   8*y*pow(x,2)*cos(2*ATANyx) + 16*x*pow(y,2)*sin(2*ATANyx) -
		   6*x*sin(2*ATANyx) + 6*y*cos(2*ATANyx) - 
		   8*pow(y,3)*cos(2*ATANyx));

  }
}

float duMCADZdy(int n, float x, float y) {

  float r,		/* convert r to x,y */
    ATANyx;		/* atan (y/x) */

  ATANyx = atan (y/x);

  r = sqrt (pow(x,2) + pow(y,2));

  switch (n) {
		
  case 1: return (0);			/* dTx/dy */

  case 2: return (1);			/* dTy/dy */

  case 3: return (4*y); 		/* dD/dy */

    /* dAx/dy */
  case 4: return (2*y*cos(2*ATANyx) - 2*x*sin(2*ATANyx));

    /* dAy/dy */
  case 5: return (2*y*sin(2*ATANyx) + 2*x*cos(2*ATANyx));

  case 6: return (6*y*x); 	/* dCx/dy */

  case 7: return 	(3*pow(x,2) + 9*pow(y,2) - 2);	/* dCy/dy */

  case 8: return (24*pow(y,3) + 24*y*pow(x,2) - 12*y);	/* dS3/dy */

    /* dTRx/dy */
  case 9: return (3*y*r*cos(3*ATANyx) - 3*x*r*sin(3*ATANyx));

    /* dTRy/dy */
  case 10: return (3*x*r*cos(3*ATANyx) + 3*y*r*sin(3*ATANyx));

    /* dAAx/dy */
  case 11: return (16*y*pow(x,2)*cos(2*ATANyx) -
		   8*pow(x,3)*sin(2*ATANyx) + 6*x*sin(2*ATANyx) -
		   8*x*pow(y,2)*sin(2*ATANyx) + 16*pow(y,3)*cos(2*ATANyx) - 
		   6*y*cos(2*ATANyx));

    /* dAAy/dy */
  case 12: return (16*y*pow(x,2)*sin(2*ATANyx) +
		   8*pow(x,3)*cos(2*ATANyx) - 6*x*cos(2*ATANyx) +
		   8*x*pow(y,2)*cos(2*ATANyx) + 16*pow(y,3)*sin(2*ATANyx) - 
		   6*y*sin(2*ATANyx));

  }
}

/* THE END */
