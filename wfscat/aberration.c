/* aberration, Jean Meeus, "Astronomical Algorithms", Willman-Bell, 1995;
 * based on secular unperturbed Kepler orbit
 *
 * the corrections should be applied to ra/dec and lam/beta at the 
 * epoch of date.
 */

#include <stdio.h>
#include <math.h>
#include <stdlib.h>

#include "P_.h"
#include "astro.h"

#define ABERR_CONST	(20.49552/3600./180.*PI)  /* aberr const in rad */
#define AB_ECL_EOD	0
#define AB_EQ_EOD	1

static void ab_aux (double mj, double *x, double *y, double lsn, int mode);

/* apply aberration correction to ecliptical coordinates *lam and *bet
 * (in radians) for a given time m and handily supplied longitude of sun,
 * lsn (in radians)
 */
void
ab_ecl (double mj, double lsn, double *lam, double *bet)
{
	ab_aux(mj, lam, bet, lsn, AB_ECL_EOD);
}

/* apply aberration correction to equatoreal coordinates *ra and *dec
 * (in radians) for a given time m and handily supplied longitude of sun,
 * lsn (in radians)
 */
void
ab_eq (double mj, double lsn, double *ra, double *dec)
{
	ab_aux(mj, ra, dec, lsn, AB_EQ_EOD);
}

/* because the e-terms are secular, keep the real transformation for both
 * coordinate systems in here with the secular variables cached.
 * mode == AB_ECL_EOD:	x = lam, y = bet	(ecliptical)
 * mode == AB_EQ_EOD:	x = ra,  y = dec	(equatoreal)
 */
static void
ab_aux (double mj, double *x, double *y, double lsn, int mode)
{
	static double lastmj = -10000;
	static double eexc;	/* earth orbit excentricity */
	static double leperi;	/* ... and longitude of perihelion */
	static char dirty = 1;	/* flag for cached trig terms */

	if (mj != lastmj) {
	    double T;		/* centuries since J2000 */

	    T = (mj - J2000)/36525.;
	    eexc = 0.016708617 - (42.037e-6 + 0.1236e-6 * T) * T;
	    leperi = degrad(102.93735 + (0.71953 + 0.00046 * T) * T);
	    lastmj = mj;
	    dirty = 1;
	}

	switch (mode) {
	case AB_ECL_EOD:		/* ecliptical coords */
	    {
		double *lam = x, *bet = y;
		double dlsun, dlperi;

		dlsun = lsn - *lam;
		dlperi = leperi - *lam;

		/* valid only for *bet != +-PI/2 */
		*lam -= ABERR_CONST/cos(*bet) * (cos(dlsun) -
				eexc*cos(dlperi));
		*bet -= ABERR_CONST*sin(*bet) * (sin(dlsun) -
				eexc*sin(dlperi));
	    }
	    break;

	case AB_EQ_EOD:			/* equatoreal coords */
	    {
		double *ra = x, *dec = y;
		double sr, cr, sd, cd, sls, cls;/* trig values coords */
		static double cp, sp, ce, se;	/* .. and perihel/eclipic */
		double dra, ddec;		/* changes in ra and dec */

		if (dirty) {
		    double eps;

		    cp = cos(leperi);
		    sp = sin(leperi);
		    obliquity(mj, &eps);
		    se = sin(eps);
		    ce = cos(eps);
		    dirty = 0;
		}

		sr = sin(*ra);
		cr = cos(*ra);
		sd = sin(*dec);
		cd = cos(*dec);
		sls = sin(lsn);
		cls = cos(lsn);

		dra = ABERR_CONST/cd * ( -(cr * cls * ce + sr * sls) +
			    eexc * (cr * cp * ce + sr * sp));

		ddec = se/ce * cd - sr * sd;	/* tmp use */
		ddec = ABERR_CONST * ( -(cls * ce * ddec + cr * sd * sls) +
			    eexc * (cp * ce * ddec + cr * sd * sp) );
		
		*ra += dra;
		range (ra, 2*PI);
		*dec += ddec;
	    }
	    break;

	default:
	    printf ("ab_aux: bad mode: %d\n", mode);
	    abort();
	    break;

	} /* switch (mode) */
}

/* For RCS Only -- Do Not Edit */
static char *rcsid[2] = {(char *)rcsid, "@(#) $RCSfile: aberration.c,v $ $Date: 2004/05/05 17:45:49 $ $Revision: 1.5 $ $Name:  $"};
