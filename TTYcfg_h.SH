case $CONFIG in
'')
	if test -f config.sh; then TOP=.;
	elif test -f ../config.sh; then TOP=..;
	elif test -f ../../config.sh; then TOP=../..;
	elif test -f ../../../config.sh; then TOP=../../..;
	elif test -f ../../../../config.sh; then TOP=../../../..;
	else
		echo "Can't find config.sh."; exit 1
	fi
	. $TOP/config.sh
	;;
esac
case "$0" in
*/*) cd `expr X$0 : 'X\(.*\)/'` ;;
esac
echo "Extracting TTYcfg.h (with variable substitutions)"
sed <<!GROK!THIS! >TTYcfg.h -e 's!^#undef!/\*#define!' -e 's!^#un-def!#undef!'
/*
 * This file was produced by running the TTYcfg_h.SH script, which
 * gets its values from config.sh, which is generally produced by
 * running Configure.
 *
 * Feel free to modify any of this as the need arises.  Note, however,
 * that running TTYcfg_h.SH again will wipe out any changes you've made.
 * For a more permanent change edit config.sh and rerun TTYcfg_h.SH.
 *
 * \$Id: Config_h.U,v 3.0.1.4 1995/09/25 09:10:49 ram Exp $
 */

/* Configuration time: $cf_time
 * Configured by: $cf_by
 * Target system: $myuname
 */

#ifndef _TTYcfg_h_
#un-def _TTYcfg_h_
#define _TTYcfg_h_

/* HAS_STRERROR:
 *	This symbol, if defined, indicates that the strerror routine is
 *	available to translate error numbers to strings. See the writeup
 *	of Strerror() in this file before you try to define your own.
 */
/* HAS_SYS_ERRLIST:
 *	This symbol, if defined, indicates that the sys_errlist array is
 *	available to translate error numbers to strings. The extern int
 *	sys_nerr gives the size of that table.
 */
#un-def HAS_STRERROR
#$d_strerror HAS_STRERROR		/**/
#un-def HAS_SYS_ERRLIST
#$d_syserrlst HAS_SYS_ERRLIST	/**/

/* VOIDSIG:
 *	This symbol is defined if this system declares "void (*signal(...))()" in
 *	signal.h.  The old way was to declare it as "int (*signal(...))()".  It
 *	is up to the package author to declare things correctly based on the
 *	symbol.
 */
#un-def VOIDSIG
#$d_voidsig VOIDSIG 	/**/

/* I_UNISTD:
 *	This symbol, if defined, indicates to the C program that it should
 *	include <unistd.h>.
 */
#un-def I_UNISTD
#$i_unistd I_UNISTD		/**/

/* CAN_PROTOTYPE:
 *	If defined, this macro indicates that the C compiler can handle
 *	function prototypes.
 */
/* _:
 *	This macro is used to declare function parameters for folks who want
 *	to make declarations with prototypes using a different style than
 *	the above macros.  Use double parentheses.  For example:
 *
 *		int main _((int argc, char *argv[]));
 */
#un-def CAN_PROTOTYPE
#$prototype CAN_PROTOTYPE	/**/
#ifdef CAN_PROTOTYPE
#un-def _
#define _(args) args
#else
#un-def _
#define _(args) ()
#endif

/* Uid_t:
 *	This symbol holds the type used to declare user ids in the kernel.
 *	It can be int, ushort, uid_t, etc... It may be necessary to include
 *	<sys/types.h> to get any typedef'ed information.
 */
#un-def Uid_t
#define Uid_t $uidtype		/* UID type */

/* VOIDFLAGS:
 *	This symbol indicates how much support of the void type is given by this
 *	compiler.  What various bits mean:
 *
 *	    1 = supports declaration of void
 *	    2 = supports arrays of pointers to functions returning void
 *	    4 = supports comparisons between pointers to void functions and
 *		    addresses of void functions
 *	    8 = suports declaration of generic void pointers
 *
 *	The package designer should define VOIDUSED to indicate the requirements
 *	of the package.  This can be done either by #defining VOIDUSED before
 *	including TTYcfg.h, or by defining defvoidused in Myinit.U.  If the
 *	latter approach is taken, only those flags will be tested.  If the
 *	level of void support necessary is not present, defines void to int.
 */
#ifndef VOIDUSED
#un-def VOIDUSED
#define VOIDUSED $defvoidused
#endif
#un-def VOIDFLAGS
#define VOIDFLAGS $voidflags
#if (VOIDFLAGS & VOIDUSED) != VOIDUSED
#un-def void
#define void int		/* is void to be avoided? */
#un-def M_VOID
#define M_VOID			/* Xenix strikes again */
#endif

/* HAS_TTYNAME:
 *	This symbol, if defined, indicates that the ttyname routine is
 *	available to get the name of a tty from a file descriptor.
 */
#un-def HAS_TTYNAME
#$d_ttyname HAS_TTYNAME		/**/

#endif
!GROK!THIS!
