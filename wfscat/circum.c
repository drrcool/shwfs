/* given a Now and an Obj with the object definition portion filled in,
 * fill in the sky position (s_*) portions.
 * calculation of positional coordinates reworked by
 * Michael Sternberg <sternberg@physik.tu-chemnitz.de>
 *  3/11/98: deflect was using op->s_hlong before being set in cir_pos().
 *  4/19/98: just edit a comment
 */

#include <stdio.h>
#include <math.h>
#include <stdlib.h>

#include "P_.h"
#include "newastro.h"
#include "preferences.h"

static int obj_planet (Now *np, Obj *op);
static int obj_binary (Now *np, Obj *op);
static int obj_2binary (Now *np, Obj *op);
static int obj_fixed (Now *np, Obj *op);
static int obj_elliptical (Now *np, Obj *op);
static int obj_hyperbolic (Now *np, Obj *op);
static int obj_parabolic (Now *np, Obj *op);
static int sun_cir (Now *np, Obj *op);
static int moon_cir (Now *np, Obj *op);
static double solveKepler (double M, double e);
static void binaryStarOrbit (double t, double T, double e, double o, double O,
    double i, double a, double P, double *thetap, double *rhop);
static void cir_sky (Now *np, double lpd, double psi, double rp, double *rho,
    double lam, double bet, double lsn, double rsn, Obj *op);
static void cir_pos (Now *np, double bet, double lam, double *rho, Obj *op);
static void elongation (double lam, double bet, double lsn, double *el);
static void deflect (double mjd1, double lpd, double psi, double rsn,
    double lsn, double rho, double *ra, double *dec);
static double h_albsize (double H);

/* given a Now and an Obj, fill in the approprirate s_* fields within Obj.
 * return 0 if all ok, else -1.
 */
int
obj_cir (Now *np, Obj *op)
{
	op->o_flags &= ~NOCIRCUM;
	switch (op->o_type) {
	case FIXED:	 return (obj_fixed (np, op));
;
	default:
	    printf ("obj_cir() called with type %d %s\n", op->o_type, op->o_name);
	    abort();
	    return (-1);	/* just for lint */
	}
}

static int
obj_fixed (Now *np, Obj *op)
{
	double lsn, rsn;	/* true geoc lng of sun, dist from sn to earth*/
	double lam, bet;	/* geocentric ecliptic long and lat */
	double ha;		/* local hour angle */
	double el;		/* elongation */
	double alt, az;		/* current alt, az */
	double ra, dec;		/* ra and dec at equinox of date */
	double rpm, dpm; 	/* astrometric ra and dec with PM to now */
	double lst;

	/* on the assumption that the user will stick with their chosen display
	 * epoch for a while, we move the defining values to match and avoid
	 * precession for every call until it is changed again.
	 * N.B. only compare and store jd's to lowest precission (f_epoch).
	 * N.B. maintaining J2k ref (which is arbitrary) helps avoid accum err
	 */
	if (epoch != EOD && (float)epoch != (float)op->f_epoch) {
	    double pr = op->f_RA, pd = op->f_dec, fe = (float)epoch;
	    /* first bring back to 2k */
	    precess (op->f_epoch, J2000, &pr, &pd);
	    pr += op->f_pmRA*(J2000-op->f_epoch);
	    pd += op->f_pmdec*(J2000-op->f_epoch);
	    /* then to epoch */
	    pr += op->f_pmRA*(fe-J2000);
	    pd += op->f_pmdec*(fe-J2000);
	    precess (J2000, fe, &pr, &pd);
	    op->f_RA = (float)pr;
	    op->f_dec = (float)pd;
	    op->f_epoch = (float)fe;
	}

	/* apply proper motion .. assume pm epoch reference equals equinox */
	rpm = op->f_RA + op->f_pmRA*(mjd-op->f_epoch);
	dpm = op->f_dec + op->f_pmdec*(mjd-op->f_epoch);

	/* set ra/dec to astrometric @ equinox of date */
	ra = rpm;
	dec = dpm;
	precess (op->f_epoch, mjed, &ra, &dec);

	/* convert equatoreal ra/dec to mean geocentric ecliptic lat/long */
	eq_ecl (mjed, ra, dec, &bet, &lam);

	/* find solar ecliptical long.(mean equinox) and distance from earth */
	sunpos (mjed, &lsn, &rsn, NULL);

	/* allow for relativistic light bending near the sun */
	deflect (mjed, lam, bet, lsn, rsn, 1e10, &ra, &dec);

	/* TODO: correction for annual parallax would go here */

	/* correct EOD equatoreal for nutation/aberation to form apparent 
	 * geocentric
	 */
	nut_eq(mjed, &ra, &dec);
	ab_eq(mjed, lsn, &ra, &dec);
	op->s_gaera = (float)ra;
	op->s_gaedec = (float)dec;

	/* set s_ra/dec -- apparent if EOD else astrometric */
	if (epoch == EOD) {
	    op->s_ra = (float)ra;
	    op->s_dec = (float)dec;
	} else {
	    /* annual parallax at time mjd is to be added here, too, but
	     * technically in the frame of equinox (usually different from mjd)
	     */
	    op->s_ra = rpm;
	    op->s_dec = dpm;
	}

	/* compute elongation from ecliptic long/lat and sun geocentric long */
	elongation (lam, bet, lsn, &el);
	el = raddeg(el);
	op->s_elong = (float)el;

	/* these are really the same fields ...
	op->s_mag = op->f_mag;
	op->s_size = op->f_size;
	*/

	/* alt, az: correct for refraction; use eod ra/dec. */
	now_lst (np, &lst);
	ha = hrrad(lst) - ra;
	hadec_aa (lat, ha, dec, &alt, &az);
	refract (pressure, temp, alt, &alt);
	op->s_alt = alt;
	op->s_az = az;

	return (0);
}


/* fill in all of op->s_* stuff except s_size and s_mag.
 * this is used for sol system objects (except sun and moon); never FIXED.
 */
static void
cir_sky (
Now *np,
double lpd,		/* heliocentric ecliptic longitude */
double psi,		/* heliocentric ecliptic lat */
double rp,		/* dist from sun */
double *rho,		/* dist from earth: in as geo, back as geo or topo */
double lam,		/* true geocentric ecliptic long */
double bet,		/* true geocentric ecliptic lat */
double lsn,		/* true geoc lng of sun */
double rsn,		/* dist from sn to earth*/
Obj *op)
{
	double el;		/* elongation */
	double f;		/* fractional phase from earth */

	/* compute elongation and phase */
	elongation (lam, bet, lsn, &el);
	el = raddeg(el);
	op->s_elong = (float)el;
	f = 0.25 * ((rp+ *rho)*(rp+ *rho) - rsn*rsn)/(rp* *rho);
	op->s_phase = (float)(f*100.0); /* percent */

	/* set heliocentric long/lat; mean ecliptic and EOD */
	op->s_hlong = (float)lpd;
	op->s_hlat = (float)psi;

	/* fill solar sys body's ra/dec, alt/az in op */
	cir_pos (np, bet, lam, rho, op);        /* updates rho */

	/* set earth/planet and sun/planet distance */
	op->s_edist = (float)(*rho);
	op->s_sdist = (float)rp;
}

/* fill equatoreal and horizontal op-> fields; stern
 *
 *    input:          lam/bet/rho geocentric mean ecliptic and equinox of day
 * 
 * algorithm at EOD:
 *   ecl_eq	--> ra/dec	geocentric mean equatoreal EOD (via mean obliq)
 *   deflect	--> ra/dec	  relativistic deflection
 *   nut_eq	--> ra/dec	geocentric true equatoreal EOD
 *   ab_eq	--> ra/dec	geocentric apparent equatoreal EOD
 *					if (PREF_GEO)  --> output
 *   ta_par	--> ra/dec	topocentric apparent equatoreal EOD
 *					if (!PREF_GEO)  --> output
 *   hadec_aa	--> alt/az	topocentric horizontal
 *   refract	--> alt/az	observed --> output
 *
 * algorithm at fixed equinox:
 *   ecl_eq	--> ra/dec	geocentric mean equatoreal EOD (via mean obliq)
 *   deflect	--> ra/dec	  relativistic deflection [for alt/az only]
 *   nut_eq	--> ra/dec	geocentric true equatoreal EOD [for aa only]
 *   ab_eq	--> ra/dec	geocentric apparent equatoreal EOD [for aa only]
 *   ta_par	--> ra/dec	topocentric apparent equatoreal EOD
 *     precess	--> ra/dec	topocentric equatoreal fixed equinox [eq only]
 *					--> output
 *   hadec_aa	--> alt/az	topocentric horizontal
 *   refract	--> alt/az	observed --> output
 */
static void
cir_pos (
Now *np,
double bet,	/* geo lat (mean ecliptic of date) */
double lam,	/* geo long (mean ecliptic of date) */
double *rho,	/* in: geocentric dist in AU; out: geo- or topocentic dist */
Obj *op)	/* object to set s_ra/dec as per equinox */
{
	double ra, dec;		/* apparent ra/dec, corrected for nut/ab */
	double tra, tdec;	/* astrometric ra/dec, no nut/ab */
	double lsn, rsn;	/* solar geocentric (mean ecliptic of date) */
	double ha_in, ha_out;	/* local hour angle before/after parallax */
	double dec_out;		/* declination after parallax */
	double dra, ddec;	/* parallax correction */
	double alt, az;		/* current alt, az */
	double lst;             /* local sidereal time */
	double rho_topo;        /* topocentric distance in earth radii */

	/* convert to equatoreal [mean equator, with mean obliquity] */
	ecl_eq (mjed, bet, lam, &ra, &dec);
	tra = ra;	/* keep mean coordinates */
	tdec = dec;

	/* get sun position */
	sunpos(mjed, &lsn, &rsn, NULL);

	/* allow for relativistic light bending near the sun.
	 * (avoid calling deflect() for the sun itself).
	 */
	if (!is_planet(op,SUN) && !is_planet(op,MOON))
	    deflect (mjed, op->s_hlong, op->s_hlat, lsn, rsn, *rho, &ra, &dec);

	/* correct ra/dec to form geocentric apparent */
	nut_eq (mjed, &ra, &dec);
	if (!is_planet(op,MOON))
	    ab_eq (mjed, lsn, &ra, &dec);
	op->s_gaera = (float)ra;
	op->s_gaedec = (float)dec;

	/* find parallax correction for equatoreal coords */
	now_lst (np, &lst);
	ha_in = hrrad(lst) - ra;
	rho_topo = *rho * MAU/ERAD;             /* convert to earth radii */
	ta_par (ha_in, dec, lat, elev, &rho_topo, &ha_out, &dec_out);

	/* transform into alt/az and apply refraction */
	hadec_aa (lat, ha_out, dec_out, &alt, &az);
	refract (pressure, temp, alt, &alt);
	op->s_alt = alt;
	op->s_az = az;

	/* Get parallax differences and apply to apparent or astrometric place
	 * as needed.  For the astrometric place, rotating the CORRECTIONS
	 * back from the nutated equator to the mean equator will be
	 * neglected.  This is an effect of about 0.1" at moon distance.
	 * We currently don't have an inverse nutation rotation.
	 */
	dra = ha_in - ha_out;	/* ra sign is opposite of ha */
	ddec = dec_out - dec;
	*rho = rho_topo * ERAD/MAU; /* return topocentric distance in AU */

	/* fill in ra/dec fields */
	if (epoch == EOD) {		/* apparent geo/topocentric */
	    ra = ra + dra;
	    dec = dec + ddec;
	} else {			/* astrometric geo/topocent */
	    ra = tra + dra;
	    dec = tdec + ddec;
	    precess (mjed, epoch, &ra, &dec);
	}
	range(&ra, 2*PI);
	op->s_ra = (float)ra;
	op->s_dec = (float)dec;
}

/* given geocentric ecliptic longitude and latitude, lam and bet, of some object
 * and the longitude of the sun, lsn, find the elongation, el. this is the
 * actual angular separation of the object from the sun, not just the difference
 * in the longitude. the sign, however, IS set simply as a test on longitude
 * such that el will be >0 for an evening object <0 for a morning object.
 * to understand the test for el sign, draw a graph with lam going from 0-2*PI
 *   down the vertical axis, lsn going from 0-2*PI across the hor axis. then
 *   define the diagonal regions bounded by the lines lam=lsn+PI, lam=lsn and
 *   lam=lsn-PI. the "morning" regions are any values to the lower left of the
 *   first line and bounded within the second pair of lines.
 * all angles in radians.
 */
static void
elongation (double lam, double bet, double lsn, double *el)
{
	*el = acos(cos(bet)*cos(lam-lsn));
	if (lam>lsn+PI || (lam>lsn-PI && lam<lsn)) *el = - *el;
}

/* apply relativistic light bending correction to ra/dec; stern
 *
 * The algorithm is from:
 * Mean and apparent place computations in the new IAU 
 * system. III - Apparent, topocentric, and astrometric 
 * places of planets and stars
 * KAPLAN, G. H.;  HUGHES, J. A.;  SEIDELMANN, P. K.;
 * SMITH, C. A.;  YALLOP, B. D.
 * Astronomical Journal (ISSN 0004-6256), vol. 97, April 1989, p. 1197-1210.
 *
 * This article is a very good collection of formulea for geocentric and
 * topocentric place calculation in general.  The apparent and
 * astrometric place calculation in this file currently does not follow
 * the strict algorithm from this paper and hence is not fully correct.
 * The entire calculation is currently based on the rotating EOD frame and
 * not the "inertial" J2000 frame.
 */
static void
deflect (
double mjd1,		/* equinox */
double lpd, double psi,	/* heliocentric ecliptical long / lat */
double rsn, double lsn,	/* distance and longitude of sun */
double rho,		/* geocentric distance */
double *ra, double *dec)/* geocentric equatoreal */
{
	double hra, hdec;	/* object heliocentric equatoreal */
	double el;		/* HELIOCENTRIC elongation object--earth */
	double g1, g2;		/* relativistic weights */
	double u[3];		/* object geocentric cartesian */
	double q[3];		/* object heliocentric cartesian unit vect */
	double e[3];		/* earth heliocentric cartesian unit vect */
	double qe, uq, eu;	/* scalar products */
	int i;			/* counter */

#define G	1.32712438e20	/* heliocentric grav const; in m^3*s^-2 */
#define c	299792458.0	/* speed of light in m/s */

	elongation(lpd, psi, lsn-PI, &el);
	el = fabs(el);
	/* only continue if object is within about 10 deg around the sun,
	 * not obscured by the sun's disc (radius 0.25 deg) and farther away
	 * than the sun.
	 *
	 * precise geocentric deflection is:  g1 * tan(el/2)
	 *	radially outwards from sun;  the vector munching below
	 *	just applys this component-wise
	 *	Note:	el = HELIOCENTRIC elongation.
	 *		g1 is always about 0.004 arc seconds
	 *		g2 varies from 0 (highest contribution) to 2
	 */
	if (el<degrad(170) || el>degrad(179.75) || rho<rsn) return;

	/* get cartesian vectors */
	sphcart(*ra, *dec, rho, u, u+1, u+2);

	ecl_eq(mjd1, psi, lpd, &hra, &hdec);
	sphcart(hra, hdec, 1.0, q, q+1, q+2);

	ecl_eq(mjd1, 0.0, lsn-PI, &hra, &hdec);
	sphcart(hra, hdec, 1.0, e, e+1, e+2);

	/* evaluate scalar products */
	qe = uq = eu = 0.0;
	for(i=0; i<=2; ++i) {
	    qe += q[i]*e[i];
	    uq += u[i]*q[i];
	    eu += e[i]*u[i];
	}

	g1 = 2*G/(c*c*MAU)/rsn;
	g2 = 1 + qe;

	/* now deflect geocentric vector */
	g1 /= g2;
	for(i=0; i<=2; ++i)
	    u[i] += g1*(uq*e[i] - eu*q[i]);
	
	/* back to spherical */
	cartsph(u[0], u[1], u[2], ra, dec, &rho);	/* rho thrown away */
}

/* estimate size in arc seconds @ 1AU from absolute magnitude, H, and assuming
 * an albedo of 0.1. With this assumption an object with diameter of 1500m
 * has an absolute mag of 18.
 */
static double
h_albsize (double H)
{
	return (3600*raddeg(.707*1500*pow(2.51,(18-H)/2)/MAU));
}

/* For RCS Only -- Do Not Edit */
static char *rcsid[2] = {(char *)rcsid, "@(#) $RCSfile: circum.c,v $ $Date: 2004/11/25 20:49:44 $ $Revision: 1.18 $ $Name:  $"};
