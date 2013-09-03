/* Routines to write/write data arrays to files.  The reader autodetects the
 * dimensions of the array and whether each row has the same number of
 * columns.  The writer is very basic with its formatting.  All dimensions
 * are assumed to have unit origin (because NR insists). */

 /* scw: 4-7-99 update: 4-8-99 : fileio.c */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "nrutil.h"
#include "fileio.h"


/* main() is just a routine to test the various functions programmed into
 * fileio.c */

	
/* fileDim()'s function is to determine the dimensions of the array
 * contained in the file.  It's pretty dumb currently: Its line buffer is
 * arbitrarily set to 2000 characters, and it doesn't test whether each line
 * has the exact same number of entries (ie valid matrix file). It returns
 * the number of rows and columns of the matrix contained therein.  It has
 * no error checking whatsoever. The size of individual data items in the
 * file is capped at 30 characters. Currently, it will only detect vectors
 * and 2d arrays. 
 */

void fileDim (char *fn, int *mxrow, int *mxcols)
{
  FILE *fp;
  int i, rcntr, ccntr,j;
  char line[100000], *pm, dummy[30];

  fp = fopen (fn,"r");

  rcntr=0;

  while (fgets (line,100000,fp) != NULL)	/* read a line from the file */
    {
      /* skip comment lines  and blank lines */ 
      if (strchr(line,'#') == NULL && strlen (line) > 1)	
	{
	  pm=line;
	  rcntr++; 	/* valid line, so increment row counter */
	  ccntr=0;	/* reset column counter for each row */
	  while (sscanf (pm,"%s", dummy) != EOF)
	    { ccntr++; 
	    pm = strstr (pm,dummy) ;	/* set pointer to item found */
	    pm += strlen (dummy);		/* set pointer to end of item */
	    }
	}
    }
  /* this returns the data for the last row of the file only --it assumes
   * that the rest of the file is fine.  Need to provide error checking
   * and clean this up later.... */

  *mxrow = rcntr;		/* return the number of rows */
  *mxcols = ccntr;	/* return the number of columns per row */


  fclose (fp);
}

/* readMatrix retrieves a 2-d array from a file.  fileDim() must be called
 * first in order to get the dimensions of the array in the file.  Again,
 * there is currently no error checking.  **dt references  an array that the
 * calling program has mallocced with matrix(). This routine also assumes
 * that the array has unit origin. Blank lines and those with a '#'
 * anywhere are ignored. */

void readMatrix (char *fn, float **dt, int nr, int nc) 
{ 
  int i,j;
  FILE *fp;
  char line[100000], dummy[30], *pm;

  fp = fopen (fn,"r");
	
  i = 1;	/* initialize row counter */
  while (fgets (line,100000,fp) != NULL)
    if (strchr(line,'#') == NULL && strlen (line) > 1)
      {
	pm=line;	/* copy pointer */
	for (j=1;j<=nc;j++)
	  {  
	    sscanf (pm,"%s", dummy);
	    pm = strstr (pm,dummy) ;	/* set pointer to item start */
	    pm += strlen (dummy);		/* set pointer to item end */
	    dt[i][j] = (float) atof (dummy);
	  }
	i++; 	/* increment row counter */
      }

  fclose (fp);

  if (i != nr+1) printf ("file row match error in %s.\n",fn);

}

void trial_readMatrix (char *fn, float **dt, int nr, int nc)
{ 
  int i,j;
  FILE *fp;
  char line[100000], dummy[30], *pm;

  fp = fopen (fn,"r");
  
  i = 1;	/* initialize row counter */
  while (fgets (line,100000,fp) != NULL)
    if (strchr(line,'#') == NULL && strlen (line) > 1)
      {
	for (j=1;j<=nc;j++)
	  sscanf (pm,"%f", dt[i][j]);
	i++; 	/* increment row counter */
      }

  fclose (fp);

  if (i != nr+1) printf ("file row match error.\n");

}

/* writeMatrix() moves a 2d array from memory into a formatted disk file */

void writeMatrix (char *nf, float **dt, int nr, int nc)
{
  FILE *fp;
  int i,j;
  
  fp = fopen (nf, "w");
  
  for (i=1;i<=nr;i++)
    {
      for (j=1;j<=nc;j++)
	fprintf (fp,"%15.7f\t", dt[i][j]);		

      fprintf (fp,"\n");	/* CR after the row has been written */
    }
  fclose (fp);
}

/* readVector copies a disk vector to a memory vector.  fileDim() must be
 * called first to get the dimensions.  *vt references the float vector
 * created by the calling program.  Blank lines and those with a '#'
 * anywhere are ignored. All vectors are assumed to have zero origin. */

void readVector (char *fn, float *vt, int nr)
{
  FILE *fp;
  int i;
  char line[50];

  fp = fopen (fn, "r");

  i = 1;	/* initialize row counter */
  while (fgets (line,50,fp) != NULL)
    if (strchr(line,'#') == NULL && strlen (line) > 1)
      {
	sscanf (line,"%f", &vt[i]);
	i++; 	/* increment row counter */
      }

  fclose (fp);

  if (i != nr+1) printf ("file row match error.\n");
}

/* writeVector() copies a memory vector to a formatted disk vector */

void writeVector ( char *fn, float *v, int nr)
{
  FILE *fp;
  int i;

  fp = fopen (fn, "w");

  for (i=1;i<=nr;i++)
    fprintf (fp, "%15.7f\n", v[i]);

  fclose (fp);
}

/* writeiVector() copies a memory vector to a formatted disk vector */

void writeiVector ( char *fn, int *v, int nr)
{
  FILE *fp;
  int i;

  fp = fopen (fn, "w");

  for (i=1;i<=nr;i++)
    fprintf (fp, "%d\n", v[i]);

  fclose (fp);
}

/* getMagOffsets() opens a centroid file and returns the magnification and
 * offset information line coded as: # X xmag ymag xoff yoff */

void getMagOffsets (char fn[], float *xm, float *ym, float *xo, float *yo)
{
  FILE *fp;
  int found, cntr;
  char line[2000], dumm[5], dumm2[5];
  
  fp = fopen (fn, "r");

  found = cntr = 0; /* used for error checking -- eventually */
  while (fgets (line,2000,fp) != NULL)
    {
      cntr++;
      if (strstr(line,"# X") != NULL )
	{
	  sscanf (line, "%s %s %f %f %f %f", dumm, dumm2, xm, ym, xo, yo) ;
	  found = 1;
	  
	  break; 		/* don't care about the rest of file */
	}
    }

  fclose (fp);


}
