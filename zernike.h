/* zernike.h */

/* 8-5-00: added monomial differential expansion */

#define ZPOLY	19		/* number of Zernike polynomials defined in code */

float upolarZ (int, float, float);	/* r,th zernike expansion */

float uZ (int, float, float);	/* monomial zernike expansion */

float duZdx (int, float, float);	/* monomial x-differentials */

float duMCADZdx (int, float, float);	/* r,th x-differentials */

float duZdy (int, float, float);	/* monomial y-differentials */

float duMCADZdy (int, float, float);	/* r,th y-differentials */


