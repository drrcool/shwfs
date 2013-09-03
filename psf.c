#include <stdlib.h>
#include <math.h>

/* assume the (x,y) coodinates for both the apertures and detector pixels are signed offsets
 * from the Z axis of the optical system. The phase values given are in um (half wave in either
 * direction) with 0 phase shift + seperation = detector_z.
 */

#define sag(w,R) (R - sqrt(R * R - w * w))

long psf(float focus_dist_z,				    /* wavefront focus distance - to hartman mask (um). */
	 float ds,					    /* shift of detector from focal plane (um). */
	 float wavelength,				    /* color of light in um. */
	 long ap_count,					    /* number of apertures in our wavefront. */
	 float *phase,					    /* variation in phase of wavefront at each aperture (um). */
	 float *ap_x, float *ap_y,			    /* (x,y) coodinates of each aperture at wavefront (um). */
	 long det_count,				    /* number of pixels that make up our detector. */
	 float *det_amp,				    /* intensity at each pixel coordinate. */
	 float *det_x, float *det_y)			    /* (x,y) coordinates of each pixel in the image in um. */
{
  int i, j;						    /* looping indices */
  double dx, dy, dz;					    /* image coordinates (um). */
  double s;						    /* OPD from point on wavefront to detector. */
  double fracWave;					    /* fractional wavelengths in OPD. */
  double xphase, yphase;				    /* vector phases corresponding to OPD. */
  float *px_sum, *py_sum;				    /* sum of the phases in x and y at each detector. */
  
  /* For each phase at each aperture of the Hartman mask, sum its contribution
   * to the phase in each detector of the image.
   */
  
  px_sum = (float *)calloc(det_count, sizeof(float));	    /* calloc inits the summing array to zero */
  py_sum = (float *)calloc(det_count, sizeof(float));

  for(i = 0; i < ap_count; i++){
    dz = focus_dist_z + ds + phase[i] - sag(hypot(ap_x[i], ap_y[i]), focus_dist_z);
    for(j = 0; j < det_count; j++){

      /* compute the OPL from aperture (i) to pixel (j) on the detector */

      dx = ap_x[i] - det_x[j];				    /* delta in x from ap coord to pixel coord (um) */
      dy = ap_y[i] - det_y[j];				    /* delta in y from ap coord to pixel coord (um) */
      s = sqrt(dx * dx + dy * dy + dz * dz);		    /* OPL */

      fracWave = fmod(s, wavelength) / wavelength;
      xphase = cos(2.0 * M_PI * fracWave);
      yphase = sin(2.0 * M_PI * fracWave);
      px_sum[j] += xphase;
      py_sum[j] += yphase;
    }							   /* loop over the detector elements. */
  }							   /* loop over the wavefront apertures. */

  /* ---------------------------------------------------------------
   * replace xbins with intensities and sum into top detector layer.
   * neglect interference terms.
   * -------------------------------------------------------------*/

  {
    double temp;
    
    for(j = 0; j < det_count; j++){
      temp = hypot(px_sum[j], py_sum[j]);
      det_amp[j] = temp * temp;				    /* square it. */
    }
  }
  free(px_sum);
  free(py_sum);
  return(1);
}
