/* This routine averages files of wavefront sensor interference spots which
   have been passed from ihaverage.tcl.  The routine adapts itself to
   the number of files passed.  
   
   This program emulates the functions of ihaverage.mcd which combines the
   files of coordinates.  Spots in each file are associated with one another
   using linked lists. A further constraint is that a given spot must exist in
   all of the files before its position is averaged (a bit too stringent, but
   effective).  After averaging and renumbering, the output averaged centroids
   are written to a file.

   scw: ihaverage.c ; update 9-13-00 

   Here are some additional comments:

   No error checking is employed.  Since the file names may only be selected
   from lists of the directories, the user can't input non-existent files.
   Since the centroids are created with know routines, they are assumed to have
   valid file structures (currently, IRAF STARFIND does the centroiding). 

   Spots are associated between the files by simply comparing coordinates
   within certain tolerance areas.  This only works when the amount of
   wavefront tilt is small compared to this area tolerance.  Larger inter-file
   tilts will require a more sophisticated routine.

   The output file contains only those spots that were determined to exist in
   all of the files.  So if a spot is missing from one file, all the
   corresponding spots are thrown out of the other files. 

   NOTE1: IRAF STARFIND tends to find spurious spots along the CCD borders.
   It's OK for this routine to include them because other routines will trim
   the valid spots with a circular pupil geometry.  

   NOTE2: ihaverage.c was adapted from the original aver.c--the latter was
   written prior to the advent of the libraries fileio.c and WFSlib.c.  This
   new routine also averages the offsets and magnifications that should be
   applied to the final centroid file for registration purposes. 
   
   9-13-00: added the upkeep of individual offsets being applied
   uniquely to each file.  Before, no offset data were used--files
   assumed to overlap (this did not work for the MMT data). Now all the spot
   files are adjusted to overlap the first file in the list--therefore it's mag
   and offset data are output to the averaged file (.av) */

#include <stdio.h> 
#include <string.h>
#include <math.h>
#define MAIN
#include "optics.h"

#define NF 50		/* Max number of files this routine accepts */
#define MS 1000		/* Max number of interference spots in each image */

float x[MS][NF], y[MS][NF];	/* arrays for storing xy data from files */
float xm, ym,xoff, yoff; /* offsets */
float XM, YM;			/* averaged magnifications */
float xof[NF], yof[NF];	/* collect indiv offsets  [0] isn't used. */

int lcntr[NF];		/* save number of spots found in each file */
char avlist[1000];	/* concat list of all averaged files */
char fout[550];

void averagethem(int fc);
double hypot (double x, double y);

main (int argc, char *argv[]) {
	
  FILE *fp;
  int i, j, cntr, test;
  char line[255];

  /* Loop through each data file, and collect all the x-y points. 
     The number of data points in each file + 1 = lcntr[i]. */

  printf ("Starting file reads");
  for (i=1;i<argc;i++) {	/* argv[0] is the name of this file! */

    lcntr[i-1] = 0;		/* Set file line counter to zero */
    fp = fopen (argv[i],"r");
    while (fgets (line,255,fp) != NULL) {
      if (strchr(line,'#') == NULL && strlen (line) > 1) {
	/* skip comment lines  and blank lines */ 
	sscanf (line, "%f %f", &x[lcntr[i-1]][i-1], &y[lcntr[i-1]][i-1]);
	lcntr[i-1]++;
      }
    }
    fclose (fp);
    
  }
  printf ("End file reads\n");

  XM = YM = 0;		/* clear sum registers */
  for (i=1;i<argc;i++) {
    printf ("getting %s\n", argv[i]);
    getMagOffsets (argv[i], &xm, &ym, &xoff, &yoff);

    XM += xm; YM += ym;
    xof[i-1]=xoff; yof[i-1]=yoff;
  }
  XM /= argc-1 ; YM /= argc-1;

  /* remove offsets from first file */
  for (j=0;j<lcntr[0];j++) {
    x[j][0] = x[j][0] - xof[0];
    y[j][0] = y[j][0] - yof[0];
  }

  /* Match overlap all files to the first file */

  for (i=1;i<argc-1;i++) {	/* don't put first (0) file in loop */
    for (j=0;j<lcntr[i-1];j++) {
      x[j][i] = (x[j][i] - xof[i]);
      y[j][i] = (y[j][i] - yof[i]);
    }
  }
			
  /* make a string containing the list of averaged files */
  sprintf (avlist,"# "); 	/* set to comment */
  for (i=1;i<argc;i++) {
    strcat (avlist, argv[i]); 
    strcat (avlist, " ");
  }
		
  /* make a file name for the averaged data.  total kludge for now */
  sprintf (fout,"%s%s", argv[1], ".av");

  averagethem(argc-1);	/* don't include argv[0] */

  return (0);

}

	
void averagethem(int fcount) {
  FILE *fp;
  int i,j,k,
    test, cntr,
    link;		/* saves array index of closest spot */
  float rmin,		/* saves closest spot's distance */
    dr;			/* dist between 2 arbitrary spots (pixels) */
  int links[lcntr[0]][fcount-1];  /* file 0 is index */
  int newlinks[lcntr[0]][fcount]; /* index is spot #, then file0,1,2... */
  float sum[lcntr[0]][2];	/* summing registers for averaging xy pairs */

  /* Starting with the first file, find spots that match in the other files.
   * A linked list array (links) is created where the array subscript is the
   * spot # in the first file.  The array elements give the number of the
   * corresponding spot in the other files (-1 indicates no spot could be
   * found). */	


  /* loop through files -- don't put first file in loop */
  for (i=1;i<fcount;i++) { 
    for (j=0;j<lcntr[0];j++) {	/* loop through spots in file 0 */
      rmin = 300.;	    /* set intially to large pixel distance > CCD/2 */
      link = -1;	    /* set array index initially to zero */
      for (k=0;k<lcntr[i];k++) { /* loop through spots in current file */
	dr = hypot (x[j][0]-x[k][i],y[j][0]-y[k][i]);
	if (dr < rmin) { 
	  rmin = dr; 
	  link = k; 
	}
      }
      links[j][i-1] = (rmin < lr) ? link : -1 ;
    }
  }

  /* re-make links (with a continous numbering) by throwing out any row with
   * a -1 in any column -- this leaves only those spots that have a match in
   * every input file. */
  cntr = 0;
  for (i=0;i<lcntr[0];i++) {
    test =0;
    for (j=0;j<fcount-1;j++)
      test += (links[i][j] == -1) ? 1 : 0;
    if (test == 0) {
      newlinks[cntr][0] = i;	/* set column 0 to index file 0 */ 
      for (k=0;k<fcount-1;k++)
	newlinks[cntr][k+1] = links[i][k]; /* fill in other column links */
      cntr++;		
    }
  }
		
  /* print file of spot associations -- for debugging */
  fp = fopen ("av_links", "w");
  for (i=0;i<cntr;i++) {
    fprintf (fp,"%8d",i);
    for (j=1;j<fcount;j++)
      fprintf (fp, "%8d", newlinks[i][j]);
    fprintf (fp,"\n");
  }
  fclose (fp);	/* close av_links pointer */

  /* Now produce averaged positions and write to file */ 
	
  fp = fopen (fout, "w");
  fprintf (fp, "%s\n", avlist);
  fprintf (fp,"# X %f %f %f %f\n", XM, YM, xof[0], yof[0]);

  for (j=0;j<cntr;j++) {	/* loop through newlinks rows */
    sum[j][0] = sum[j][1] = 0;
    for (i=0;i<fcount;i++) { 
      sum[j][0] += x[newlinks[j][i]][i];
      sum[j][1] += y[newlinks[j][i]][i];
    }
    sum[j][0] /= (float)fcount;
    sum[j][1] /= (float)fcount;

    sum[j][0] += xof[0]; /* re-apply original file0 offsets to data */
    sum[j][1] += yof[0];
    fprintf (fp, "%10.3f %10.3f\n", sum[j][0], sum[j][1]);
  }

  fclose (fp);

}

double hypot (double x, double y) {
  return (sqrt (pow(x,2) + pow (y,2)));
}

/* THE END */
