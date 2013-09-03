/* wfs_image.c is a stand-alone routine that makes an XPM image out of a 2D
 * array.  It stores the image in a standard file name, so tcl can easily
 * display it.  scw: 7-27-99 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/* call with 2D array, rows, columns. Also add clr which is color 1 or B/W
 * 0, and rng which is the range to be plotted starting from the minimum to
 * rng % of the maximum (0 plots nothing up to 100 for the full image). mag
 * is the # of times to replicate each pixel on the display in order to
 * scale it up for viewing and seeing the pixels in the image.  Following
 * the numerical recipes convention, all arrays are 1-based.  The range of
 * ascii chars are 0x20 = 32 = " " to 0x7E = 126 = "~" for a span of 94
 * intensity values if 1 char/pixel is used. However, most of these colors
 * are not discernable from one another, so fewer are used. */

/* NOTE: this routine has a special transparent pixel that is rendered
 * whenever it encounters at -100,000 intensity value */

/* NOTE2: This routine could stand a good cleaning! */

makeXPM (float **img, int rw, int cl, int clr, int rng, int mag, char *fn)  
{
  FILE *fp;

  float amx, amin,	/* image array max and min values */
    xpm_scale, k;

  int i, j, ii, jj;
  const NCOL = 40;	/* # of XPM colors used to render image */
	
  /* set up image scaling */

  /* find max and minimum intensity of image */
  amx = amin = 0; /* kludge for now -- needs to be a real data value that
		     doesn't equal -100000 */

  for (i=1;i<=rw;i++)
    {
      for (j=2;j<=cl;j++)
	{
	  if (img[i][j] != -100000) {
	    amx = (img[i][j] > amx) ? img[i][j] : amx;
	    amin = (img[i][j] < amin) ? img[i][j] : amin; 
	  }
	}
    }
			
  /* set the scale of image units/XPM intensity unit */

  amx = amx * rng/100;	/* set new max using range scaling */
  xpm_scale = (amx - amin)/(float)NCOL;			

  /* now write xpm file */

  fp = fopen(fn,"w");

  fprintf (fp,"/* XPM */\n");
  fprintf (fp, "static char * wavefront[] = {\n");
  fprintf (fp, "/* width height num_colors chars_per_pixel */\n");
  /* add 1 color to table for transparent pixel */
  fprintf (fp,"\"%d %d %d 1\",\n", rw*mag, cl*mag, NCOL+1);
  fprintf (fp,"/* colors */\n");

  /* make xpm color mapping table (use 100-119 ascii chars). This will
   * define NCOL color definitions. The first and last colors correspond
   * to amin and amax respectively. */

  fprintf (fp,"\"%c\tc none\",\n", 32);	/* set space to transparent */
  for (i=100;i<=139;i++)
    fprintf (fp,"\"%c\tc #20%2x%2x\",\n", i,
	     (i-100)*(255-100)/NCOL+100, 255 - (i-100)*(255-100)/NCOL);
  /* funny since it clips lowest 25% of colors which look black*/
	
  /* now fill in intensity values of pixels */
  fprintf (fp, "/* pixels */\n");
  for (i=1;i<=rw;i++)
    {
      for (ii=1;ii<=mag;ii++) /* vertical magnification */
	{
	  fprintf (fp,"\"");
	  for (j=1;j<=cl;j++)
	    {
	      /* k spans 1 to NCOL = the color table # for the pixel */
	      /* the first test checks for range clipping too */
	      if (img[i][j] != -100000) {
		k = (img[i][j] > amx) ? amx - amin : img[i][j] - amin;
		k =  k/xpm_scale;
	      }

	      if (k>=NCOL) k = NCOL-1; /* colors are zero-based */
	      k = (img[i][j] == -100000) ? 32 : k + 100;
	      for (jj=1;jj<=mag;jj++) /* horizontal magnification */
		{
		  fprintf (fp,"%c", (int)k );
		}
	    }
	  if ((i < rw) || ( i==rw && ii<mag)) fprintf (fp,"\",\n");
	}
    }

  fprintf (fp,"\"\n");	/* no trailing comma on last line */
  fprintf (fp,"};\n");
  fclose (fp);
}

			

	

	
	
