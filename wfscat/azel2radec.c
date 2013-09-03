#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "P_.h"
#include "astro.h"
#include "circum.h"

extern void time_fromsys P_((Now *));

int main(int argc, char *argv[]) {

  Now *np;
  Now now;
  char ra_hms[11], dec_dms[12];
  double az, el;
  double ha, dec; 

  ha = 0.0;
  dec = 90.0;

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

  az = degrad(atof(argv[1]));
  el = degrad(atof(argv[2]));

  aa_hadec(degrad(31.689), el, az, &ha, &dec);

  printf("%f %f\n", radhr(ha), raddeg(dec));

}
