#include <stdio.h>
#include <sys/time.h>
#include <time.h>

#include "P_.h"
#include "circum.h"

/*
 * Shamelessly ripped from E.C. Downey's XEphem
 * Gets time from system
 */
void time_fromsys (Now *np) {
#if defined(__STDC__)
  time_t t;
#else
  long t;
#endif
 
  t = time(NULL);
    
  /* t is seconds since 00:00:00 1/1/1970 UTC on UNIX systems;
   * mjd was 25567.5 then.
   */
  mjd = 25567.5 + t/3600.0/24.0;

  (void) tz_fromsys(np);

}

/* given the mjd within np, try to figure the timezone from the os.
 * return 0 if it looks like it worked, else -1.
 *
 * Shamelessly ripped from E.C. Downey's XEphem
 */
int tz_fromsys (Now *np) {
  struct tm *gtmp;
  time_t t;
  
  t = (time_t)((mjd - 25567.5) * (3600.0*24.0) + 0.5);
  
  /* try to find out timezone by comparing local with UTC time.
   * GNU doesn't have difftime() so we do time math with doubles.
   */
  gtmp = gmtime (&t);
  if (gtmp) {
    double gmkt, lmkt;
    struct tm *ltmp;

    gtmp->tm_isdst = 0;       /* _should_ always be 0 already */
    gmkt = (double) mktime (gtmp);
    
    ltmp = localtime (&t);
    ltmp->tm_isdst = 0;       /* let mktime() figure out zone */
    lmkt = (double) mktime (ltmp);

    tz = (gmkt - lmkt) / 3600.0;
    (void) strftime (tznm, sizeof(tznm)-1, "%Z", ltmp);
    return (0);
  } else
    return (-1);
}
 
/* given an mjd, return it modified for terrestial dynamical time */
double mm_mjed (Now *np) {
  return (mjd + deltat(mjd)/86400.0);
}
