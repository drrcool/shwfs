/* as2binary.c 	scw: update: 10-19-99  		*/

/* This routine reads in the BCV matrices and then re-saves them to binary
 * format.  Continually reading in a very large matrix stored as ascii turns
 * out to be very time consuming (i.e. using readMatrix()).  This routine is
 * intended to be used only once, and then ihwfs.tcl and its associated
 * routines will simply read the file in binary format.  There are tests
 * herein since this is the first binary data I've ever messed around with. 
 *
 * 1-10-02 moved files from c_devel to current directory */

 #include <stdio.h>
 #include <stdlib.h>
 #include <math.h>
 #include "fileio.h"
 #include "nrutil.h"
 #include <fcntl.h>


 main (int argc, char *argv[])
 {
	const int ACT = 104;	/* # MMT axial actuators */
	const int NODE = 3222;	/* # BCV nodes on mirror surface */
	const float BRAD = 3.25e6;  /* BCV radius in microns */

	FILE *fp;

	float **nodes,		/* BCV node coordinates */
		**rth,			/* BCV nodes in dimensionless polar coords */
		**Surf2Act,		/* convert surface displacement vector to actuator 
							force vector */
		**Surf2Actb,		/* act forces to surf displacements */
		*disp;			/* surface displacement vecctor at bcv nodes */

	int i, j,
		*vmask;


	Surf2Act = matrix (1, ACT, 1, NODE);
	Surf2Actb = matrix (1, ACT, 1, NODE);	/* test binary file */

	readMatrix ("Surf2ActTEL_32", Surf2Act, ACT, NODE); 
	printf ("Done reading Surf2Act the long way\n");
	fflush (stdout);

	fp= fopen ("Surf2ActTEL_32.bin", "w");
	printf ("Done opening STEST\n");
	fflush (stdout);
	fwrite (&Surf2Act[1][1], NODE*ACT,sizeof (float),fp);	/* strange pointer
											Surf2Act was created with NR amd
											its offset index function */ 
	fclose (fp);
	printf ("Done writing the binary file\n");
	fflush (stdout);

	printf ("Starting to read binary Surf2Act\n");
	fflush (stdout);

	fp = fopen ("Surf2ActTEL_32.bin", "r");

	fread (&Surf2Actb[1][1], NODE*ACT,sizeof (float), fp);

	fclose (fp);

	printf ("Done reading binary file\n");
	fflush (stdout);

	

	/* read BCV node coords (mm), first column is BCV ID#. */
	nodes = matrix (1, NODE, 1, 4);
	rth = matrix (1, NODE, 1, 2);
	readMatrix ("nodecoor", nodes, NODE, 4);

	/* re-save Surf2Act in binary format */

	


	/* convert nodes to dimensionless polar coords */

for (i=1; i<=NODE; i++)
	{
		rth[i][1] = (sqrt ( nodes[i][1]*nodes[i][1] + nodes[i][2]*nodes[i][2]))/BRAD;

		rth[i][2] = atan2 (nodes[i][2],nodes[i][1]);
	}



	 for (i=1;i<=10;i++)
	 	printf ("%5.1f %5.1f\n ", Surf2Act[i][1], Surf2Actb[i][1]);
	 for (i=1;i<=10;i++)
	 	printf ("%5.1f %5.1f\n ", Surf2Act[i][ACT], Surf2Actb[i][ACT]);

	printf ("Last is %f %f\n", Surf2Act[ACT][NODE], Surf2Actb[ACT][NODE]);


	




 free_matrix (Surf2Act, 1, ACT, 1, NODE);
 free_matrix (Surf2Actb, 1, ACT, 1, NODE);
 free_matrix (nodes, 1, NODE, 1, 4);
 free_matrix (rth, 1, NODE, 1, 2);

 return (0);
 }

