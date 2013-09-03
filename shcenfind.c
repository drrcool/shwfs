/* shcenfind.c: scw: 8-26-02 */

/* This routine reads a centroid file (currently produced with iraf
 * starfind), sorts the centroids into rows and columns, determines the x
 * and y average magnifications, and estimates the center position of the
 * spot diagram.  The information is written to the ihwfs-style header, and
 * the whole thing sent back to overwrite the input (.cntr) file. This
 * routine will eventually replace overlay.tcl (which provides this
 * information through an interactive mask overlay).
 *
 * 8-26-02: centroid file must be simplified by shwfs.tcl prior to input
 * here (which it is). This includes stripping out border artifacts.
 *
 * 8-27-02: solve for average x and y or each column, row respectively, and
 * tally # of spots in each.
 *
 * 9-02-02: added solve for spot pattern x,y and xmag,ymag.  ymag is
 * adjusted for hexagonal geometry of lenslet array, so it gives a 1:1 mag
 * to use with xmag.  This was necesaary because associateSpots() takes an
 * average of these mags, so they need to be normalized. Also added removal
 * of border artifacts that come about from Downey's old apogee drivers.
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "fileio.h"
#include "nrutil.h"
#include "optics.h"

 /* pass the arguments as argv[1] = centroid filename */


int main (int argc, char *argv[])
{
  int Ncr, Ncc,			  /* number of centroid rows/cols in file */
    mxr, mxc,                     /* max # rows and columns in spot pattern */
    *keep, cntr, success, ncignore, nrignore, *rows, *cols,		
    i,j,xf,yf,nspots;

#ifdef F9
  const float del = 5;	/* +/- tolerance for row/col IDs */
#endif
#ifdef MMIRS
  const float del = 5;	/* +/- tolerance for row/col IDs */
#endif
#ifdef F5
  const float del = 10;	/* +/- tolerance for row/col IDs */
#endif

  const float xymratio = XYMRATIO;	/* xmag/ymag for hex geometry */

  char *fcen = argv[1];	/* centroid file name */
	
  float **xy,		/* storage for xy controids */
    **col_avx, **row_avy,	/* average x, y of each column, row */
    **xyrc,		/* row column IDs: rc[i][1] = column, rc[i][2] = row */
    xdel, ydel,
    highy, lowy, xmag, ymag, highx, lowx,
    pattern_xav, pattern_yav; /* xy center of entire spot pattern */

  FILE *outfp;
  highy = 0;
  lowy = 0;
  highx = 0;
  lowx = 0;

  success = 0; /* set success of this routine to no (0) */
	
  /* read in centroids */
  fileDim (fcen, &Ncr, &Ncc); /* get rows/cols of centroid file */
  xy = matrix (1, Ncr, 1, Ncc); /* store original xy centroids */
  readMatrix (fcen, xy, Ncr, Ncc);

  /* check centroids for spurious spots on borders */
  /* this is kind of redundant now, but will keep around just in case. */
  keep = ivector(1,Ncr);	/* keep (1) the spot or not (0) */
  cntr = 0;
  for (i=1;i<=Ncr;i++)
    {
      keep[i] = 0; /* default to throw out centroid */
      /* bad spots are near x = y = 0 border */
      if (xy[i][1] > 5 && xy[i][2] > 5 && xy[i][1] < 507 && xy[i][2] < 507) 
	{
	  keep[i] = 1;
	  cntr++; /* total number of centroids to keep */
	}
    }

  xyrc = matrix (1, cntr, 1,4); /* new xy, and row column IDs for each spot */
  /* printf ("rows in input file: %d\n", cntr); */

  /* now make new xy list with only relevant spots */
  j = 0;
  for (i=1;i<=Ncr;i++)
    {
      if (keep[i] == 1)
	{
	  j++;
	  /* printf ("re-saving centroid # %d\n", i); */
	  xyrc[j][1] = xy[i][1];
	  xyrc[j][2] = xy[i][2];
	}
    }

  /* set row/col ID of first centroid to 1 and 1 */
  xyrc[1][3] = 1; 	/* column ID */
  xyrc[1][4] = 1;	/* row ID */
  mxc = 1; mxr=1;	/* set max column/row currently defined */

  /* loop through remaining centroids.  Determine if the row and column
   * they reside in is already defined or new ID(s) need to be made. */
  for (i=2;i<=cntr;i++)
    {
      /* loop through already-defined IDs and see if there is a match */
      xf = 0; yf = 0; /* flags, if =1, then ID exists */
      for (j=1;j<i;j++)
	{
	  xdel = fabs(xyrc[i][1] - xyrc[j][1]); /* row/col tolerances */
	  ydel = fabs(xyrc[i][2] - xyrc[j][2]);
	  if (xdel <= del && !xf) 
	    {
	      xyrc[i][3] = xyrc[j][3];	/* assign existing ID */
	      xf = 1;
	    }

	  if (ydel <= del && !yf) 
	    {
	      xyrc[i][4] = xyrc[j][4];
	      yf = 1;
	    }
	}	

      /* ID does not yet exist--create a new ID */
      /* columns have constant x */
      if (!xf) xyrc[i][3] = ++mxc; 
      if (!yf) xyrc[i][4] = ++mxr;
    }

  writeMatrix ("xyrc.tst", xyrc, cntr, 4);

  ncignore = nrignore = 0;

  /* printf ("# rows = %d, # cols = %d\n", mxr, mxc); */

  /* ---------------------------------------------------------- */

  /* post-process rows/columns */

  col_avx = matrix(1,mxc,1,2); /* average x of each column, and # of spots */
  row_avy = matrix(1,mxr,1,2); /* average y or each row  and # of spots */

  /* zero the arrays prior to summing */
  for (i=1;i<=mxc;i++)
    {
      col_avx[i][1] = col_avx[i][2] = 0;
    }

  for (i=1;i<=mxr;i++)
    {
      row_avy[i][1] = row_avy[i][2] = 0;
    }

  /* sum the x value of each column into col_avx according to its ID, and
   * keep track of the number of spots in each column */
  for (i=1;i<=cntr;i++)
    {
      col_avx[(int)xyrc[i][3]][1] += xyrc[i][1]; 	/* sum x value */
      ++col_avx[(int)xyrc[i][3]][2]; 			/* incr # of spots in column */
    }

  /* replace sums with the average x of each column */ 
  for (i=1;i<=mxc;i++)
    {
      col_avx[i][1] /= col_avx[i][2]; 	/* replace sum with average */
      if (i == 1) {
	if (col_avx[i][2] > 2) {
	  lowx = col_avx[i][1];
	} else {
	  lowx = col_avx[i+1][1];
	}
      }

      /* find the highest and lowest column */
      if (col_avx[i][2] <= 2) {
	ncignore++;
      } else {
	if (col_avx[i][1] > highx) highx = col_avx[i][1];
	if (col_avx[i][1] < lowx) lowx = col_avx[i][1];
      }
      /* printf ("col %d average is %f with %f spots\n", i, col_avx[i][1],
	 col_avx[i][2]);*/
    }

  /* process average y of each row */

  /* sum each y into row_avy array given by its ID, and keep track of how
   * many spots are in each row */
  for (i=1;i<=cntr;i++)
    {
      row_avy[(int)xyrc[i][4]][1] += xyrc[i][2];
      ++row_avy[(int)xyrc[i][4]][2];
    }

  /* replace sums with average y of each row */
  /* also solve for the highest and lowest rows */
  for (i=1;i<=mxr;i++)
    {
      row_avy[i][1] /= row_avy[i][2];	/* replace sum with average */
      if (i == 1) {
	if (row_avy[i][2] > 2) {
	  lowy = row_avy[i][1];
	} else {
	  lowy = row_avy[i+1][1];
	}
      }

      /* find the highest and lowest row */
      if (row_avy[i][2] <= 2) {
	nrignore++;
      } else {
	if (row_avy[i][1] > highy) highy = row_avy[i][1];
	if (row_avy[i][1] < lowy) lowy = row_avy[i][1];
      }
      /* printf ("i is %d, highy = %f, lowy = %f\n", i, highy, lowy); */
	
      /* printf ("row %d average is %f with %f spots\n", i, row_avy[i][1],
	 row_avy[i][2]); */
    }

  /* ---------------------------------------------------------- */

  /* magnifications in pixels/<col> or pixels/<row> */
  xmag = (highx - lowx) / (mxc - ncignore);
  ymag = (highy - lowy) / (mxr - nrignore);
  /* correct for hexagonal magnification -- this is done so all other
   * routines which expect similar xy mags won't break -- e.g.
   * getZernikesAndphases, ihaverage, etc */
  ymag *= xymratio; 	/* correct ymag for hex geometry */

  /* determine the spot pattern center */
  if (argc > 2) {
    pattern_xav = atof(argv[2]);
    pattern_yav = atof(argv[3]);
  } else {
    pattern_xav = 0.0;
    nspots = 0;
    for (i=1; i<=mxc; i++) {
      if (col_avx[i][2] >= 3) {
	pattern_xav += col_avx[i][1]*col_avx[i][2];
	nspots += col_avx[i][2];
      }
    }
    pattern_xav /= nspots;

    pattern_yav = 0.0;
    nspots = 0;
    for (i=1; i<=mxr; i++) {
      if (row_avy[i][2] >= 3) {
	pattern_yav += row_avy[i][1]*row_avy[i][2];
	nspots += row_avy[i][2];
      }
    }
    pattern_yav /= nspots;
  }

  /* printf ("Ncr is %d\n", Ncr);
     printf ("highy = %f, lowy = %f\n", highy, lowy);
     printf ("highx = %f, lowx = %f\n", highx, lowx);
     printf ("pattern xav is %f, yav is %f\n", pattern_xav, pattern_yav);
     printf ("xmag = %f, ymag = %f\n", xmag, ymag); */ 

  /* write a modified file with ihwf-style header and omitting the border
   * artifacts. This overwrites the .cntr file passed to this routine as
   * argv[1]. */

  /* printf (" getting ready to write new output file\n"); */
  /* printf ("output file is %s\n", fcen); */
  outfp = fopen (fcen, "w");

  /* write ihwfs-style header to .cntr file */
  fprintf (outfp, "# X %.4f %.4f %.4f %.4f\n", xmag, ymag, pattern_xav, 
	   pattern_yav);
      
  /* write new centroids to .cntr file (no border artifacts) */
  for (i=1;i<=cntr;i++)
    fprintf (outfp, "%.5f %.5f\n", xyrc[i][1], xyrc[i][2]);
  
  fclose (outfp);

  free_matrix (xy,1,Ncr,1,Ncc);
  free_matrix (xyrc,1,cntr,1,4);
  free_ivector (keep, 1, Ncr);
  free_matrix (col_avx,1,mxc,1,2);
  free_matrix (row_avy,1,mxr,1,2);
	
  printf ("%d %d\n", mxr-nrignore, mxc-ncignore); /* send # rows/columns found to pipe */
  return (0); /* required for proper tcl command pipeline termination */
}
