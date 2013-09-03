#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "P_.h"
#include "astro.h"
#include "circum.h"

extern int xe2fetch P_((char *file, Now *np, 
			double ra, double dec, 
			double fov, double mag, 
			ObjF **opp, char *msg));
extern void time_fromsys P_((Now *));

int main(int argc, char *argv[]) {
  Now *np;
  Now now;
  ObjF *op = NULL;
  char msg[256];
  char *wfsroot, *filename, ra_hms[50], dec_dms[50];
  double ra, dec, fov, mag, dra, ddec, dist, fo_ra, fo_dec;
  int nop = 0;
  int i;

  now.n_mjd = 0.0;
  now.n_lat = degrad(31.689);
  now.n_lng = degrad(-110.885);
  now.n_tz  = 7.0;
  now.n_temp = 20.0;
  now.n_pressure = 700.0;
  now.n_elev = 2580.0/ERAD;
  now.n_dip = 0.0;
  now.n_epoch = EOD;
  sprintf(now.n_tznm, "UTC-7");

  np = &now;

  time_fromsys(np);

  ra = hrrad(atof(argv[1]));
  dec = degrad(atof(argv[2]));
  fov = degrad(atof(argv[3]));
  mag = atof(argv[4]);

  /* precess(mjd, J2000, &ra, &dec); */

  if (getenv("WFSROOT")) {
    wfsroot = getenv("WFSROOT");
    filename = (char *) malloc(strlen(wfsroot) + 20);
    strcpy(filename, wfsroot);
    strcat(filename, "/wfscat/tycho.xe2");
  } else {
    filename = "/mmt/shwfs/wfscat/tycho.xe2";
  }

  nop = xe2fetch(filename, np, ra, dec, fov, mag, &op, msg);

  for (i=0; i<nop; i++) {
    dist = raddeg( acos( sin(op[i].fo_dec)*sin(dec) + 
			 cos(op[i].fo_dec)*cos(dec)*cos(ra-op[i].fo_ra) 
			 ) 
		   );
    dist *= 60.0;

    fo_ra = radhr(op[i].fo_ra);
    fo_dec = raddeg(op[i].fo_dec);

    sprintf(ra_hms, "%02d:%02d:%05.2f", (int) fo_ra, 
	    (int) ((fo_ra - (int)fo_ra)*60.0),
	    ( (fo_ra - (int)fo_ra)*60.0 - 
	      (int) ((fo_ra - (int)fo_ra)*60.0) )*60.0);

    if (fo_dec < 0.0 && (int)fo_dec >= 0) {
      sprintf(dec_dms, "-%02d:%02d:%06.3f", (int)fo_dec, 
	      abs( (int) ((fo_dec - (int)fo_dec)*60.0) ),
	      fabs( ( (fo_dec - (int)fo_dec)*60.0 - 
		      (int) ((fo_dec - (int)fo_dec)*60.0) )*60.0) );
    } else {
      sprintf(dec_dms, "%+03d:%02d:%06.3f", (int)fo_dec, 
	      abs( (int) ((fo_dec - (int)fo_dec)*60.0) ),
	      fabs( ( (fo_dec - (int)fo_dec)*60.0 - 
		      (int) ((fo_dec - (int)fo_dec)*60.0) )*60.0) );
    }

    printf("%15s  %4.1f mag  %2s  %c  %s  %s  %+07.3f  %+07.2f  %9.2f\n", op[i].co_name, op[i].co_mag/MAGSCALE, op[i].fo_spect, op[i].fo_class, ra_hms, dec_dms, 0.1*op[i].fo_pma/cos(op[i].fo_dec), 0.1*op[i].fo_pmd, dist);
  }

  return(0);
}
