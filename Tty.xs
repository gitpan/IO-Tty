#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef PerlIO
typedef int SysRet;
typedef PerlIO * InOutStream;
#else
# define PERLIO_IS_STDIO 1
# define PerlIO_fileno fileno
typedef int SysRet;
typedef FILE * InOutStream;
#endif

#define NOT_HERE(s,r) \
	do { \
	    croak("%s not implemented on this architecture", s); \
	    RETVAL = r; \
	} while(0)

#include "config.h"

/* Copyright (c) 1993
 *      Juergen Weigert (jnweiger@immd4.informatik.uni-erlangen.de)
 *      Michael Schroeder (mlschroe@immd4.informatik.uni-erlangen.de)
 * Copyright (c) 1987 Oliver Laumann
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program (see the file COPYING); if not, write to the
 * Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 ****************************************************************
 */

#ifdef I_UNISTD
# include <unistd.h>
#endif

#if !defined(SVR4) && defined(__svr4__)
# define SVR4
#endif

#if defined(_POSIX_VERSION) && !defined(POSIX)
# define POSIX
#endif

#if defined(BSDI)   || defined(__386BSD__) || defined(_CX_UX) || \
    defined(M_UNIX) || defined(M_XENIX)
# include <signal.h>
#endif

#ifdef ISC
# include <sys/bsdtypes.h>
#endif

#ifndef linux /* all done in <errno.h> */
extern int errno;
#endif /* linux */


#if !defined(HAS_STRERROR)  && !defined(strerror)
# if defined(HAS_SYS_ERRLIST)
#   define strerror(errno) sys_errlist[errno]
# endif
#endif

#if (defined(TIOCGWINSZ) || defined(TIOCSWINSZ)) && defined(M_UNIX)
# include <sys/stream.h>
# include <sys/ptem.h>
#endif

/*****************************************************************
 *    terminal handling
 */

#ifdef POSIX
# include <termios.h>
# ifdef hpux
#  include <bsdtty.h>
# endif /* hpux */
# ifdef NCCS
#  define MAXCC NCCS
# else
#  define MAXCC 256
# endif
#else /* POSIX */
# ifdef TERMIO
#  include <termio.h>
#  ifdef NCC
#   define MAXCC NCC
#  else
#   define MAXCC 256
#  endif
#  ifdef CYTERMIO
#   include <cytermio.h>
#  endif
# else /* TERMIO */
#  include <sgtty.h>
# endif /* TERMIO */
#endif /* POSIX */


/*****************************************************************
 *    file stuff
 */

#ifndef F_OK
#define F_OK 0
#endif
#ifndef X_OK
#define X_OK 1
#endif
#ifndef W_OK
#define W_OK 2
#endif
#ifndef R_OK
#define R_OK 4
#endif

#ifndef S_IFIFO
#define S_IFIFO  0010000
#endif
#ifndef S_IREAD
#define S_IREAD  0000400
#endif
#ifndef S_IWRITE
#define S_IWRITE 0000200
#endif
#ifndef S_IEXEC
#define S_IEXEC  0000100
#endif

#if defined(S_IFIFO) && defined(S_IFMT) && !defined(S_ISFIFO)
#define S_ISFIFO(mode) (((mode) & S_IFMT) == S_IFIFO)
#endif
#if defined(S_IFSOCK) && defined(S_IFMT) && !defined(S_ISSOCK)
#define S_ISSOCK(mode) (((mode) & S_IFMT) == S_IFSOCK)
#endif
#if defined(S_IFCHR) && defined(S_IFMT) && !defined(S_ISCHR)
#define S_ISCHR(mode) (((mode) & S_IFMT) == S_IFCHR)
#endif
#if defined(S_IFDIR) && defined(S_IFMT) && !defined(S_ISDIR)
#define S_ISDIR(mode) (((mode) & S_IFMT) == S_IFDIR)
#endif

#if !defined(O_NONBLOCK) && defined(O_NDELAY)
# define O_NONBLOCK O_NDELAY
#endif

#if !defined(FNBLOCK) && defined(FNONBLOCK)
# define FNBLOCK FNONBLOCK
#endif
#if !defined(FNBLOCK) && defined(FNDELAY)
# define FNBLOCK FNDELAY
#endif
#if !defined(FNBLOCK) && defined(O_NONBLOCK)
# define FNBLOCK O_NONBLOCK
#endif

/*****************************************************************
 *    signal handling
 */

#ifdef VOIDSIG
# define SIGRETURN
# define sigret_t void
#else
# define SIGRETURN return 0;
# define sigret_t int
#endif

/* Geeeee, reverse it? */
#if defined(SVR4) 			|| \
   (defined(SYSV) && defined(ISC)) 	|| \
    defined(_AIX) 			|| \
    defined(linux) 			|| \
    defined(ultrix) 			|| \
    defined(__386BSD__) 		|| \
    defined(BSDI) 			|| \
    defined(POSIX) 			|| \
    defined(NeXT)
# define SIGHASARG
#endif

#ifdef SIGHASARG
# define SIGPROTOARG   (int)
# define SIGDEFARG     (sigsig) int sigsig;
# define SIGARG        0
#else
# define SIGPROTOARG   (void)
# define SIGDEFARG     ()
# define SIGARG
#endif

#ifndef SIGCHLD
# define SIGCHLD SIGCLD
#endif

#if defined(POSIX) || defined(hpux)
# define signal xsignal
#else
# ifdef USESIGSET
#  define signal sigset
# endif /* USESIGSET */
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>

#if !defined(sun) 
#include <sys/ioctl.h>
#endif

#if defined(sun) && defined(LOCKPTY) && !defined(TIOCEXCL)
#include <sys/ttold.h>
#endif

#ifdef ISC
# include <sys/tty.h>
# include <sys/sioctl.h>
# include <sys/pty.h>
#endif

#ifdef sgi
# include <sys/sysmacros.h>
#endif /* sgi */

#ifdef SVR4
# include <sys/stropts.h>
#endif

/*
 * if no PTYRANGE[01] is in the config file, we pick a default
 */
#ifndef PTYRANGE0
# define PTYRANGE0 "pqr"
#endif
#ifndef PTYRANGE1
# define PTYRANGE1 "0123456789abcdef"
#endif

static Uid_t eff_uid;

#if !(defined(sequent) || defined(_SEQUENT_) || defined(SVR4))
# ifdef hpux
static char PtyProto[] = "/dev/ptym/ptyXY";
static char TtyProto[] = "/dev/pty/ttyXY";
# else
static char PtyProto[] = "/dev/ptyXY";
static char TtyProto[] = "/dev/ttyXY";
# endif /* hpux */
#endif

static void initpty _((int));

/***************************************************************/

static void
initpty(f)
int f;
{
#ifdef POSIX
  tcflush(f, TCIOFLUSH);
#else
# ifdef TIOCFLUSH
  (void) ioctl(f, TIOCFLUSH, (char *) 0);
# endif
#endif
#ifdef LOCKPTY
  (void) ioctl(f, TIOCEXCL, (char *) 0);
#endif
}

/*
 *    Signal handling
 */

#ifdef POSIX
sigret_t (*xsignal(sig, func)) _(SIGPROTOARG)
int sig;
sigret_t (*func) _(SIGPROTOARG);
{
  struct sigaction osa, sa;
  sa.sa_handler = func;
  (void)sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;
  if (sigaction(sig, &sa, &osa))
    return (sigret_t (*)_(SIGPROTOARG))-1;
  return osa.sa_handler;
}

#else
# ifdef hpux
/*
 * hpux has berkeley signal semantics if we use sigvector,
 * but not, if we use signal, so we define our own signal() routine.
 */
void (*xsignal(sig, func)) _(SIGPROTOARG)
int sig;
void (*func) _(SIGPROTOARG);
{
  struct sigvec osv, sv;

  sv.sv_handler = func;
  sv.sv_mask = sigmask(sig);
  sv.sv_flags = SV_BSDSIG;
  if (sigvector(sig, &sv, &osv) < 0)
    return (void (*)_(SIGPROTOARG))(BADSIG);
  return (osv.sv_handler);
}
# endif	/* hpux */
#endif	/* POSIX */

/***************************************************************/

#if defined(OSX) && !defined(PTY_DONE)
#define PTY_DONE
int
OpenPTY(ttyn)
SV *ttyn;
{
  register int f;
  char TtyName[32];
  if ((f = open_controlling_pty(TtyName)) < 0)
    return -1;
  initpty(f);
  sv_setpv(ttyn,TtyName);
  return f;
#endif

/***************************************************************/

#if (defined(sequent) || defined(_SEQUENT_)) && !defined(PTY_DONE)
#define PTY_DONE
int
OpenPTY(ttyn)
SV *ttyn;
{
  char *m, *s;
  register int f;
  char PtyName[32], TtyName[32];


  if ((f = getpseudotty(&s, &m)) < 0)
    return -1;
#ifdef _SEQUENT_
  fvhangup(s);
#endif
  strncpy(PtyName, m, sizeof(PtyName));
  strncpy(TtyName, s, sizeof(TtyName));
  initpty(f);
  sv_setpv(ttyn,TtyName);
  return f;
}
#endif

/***************************************************************/

#if defined(__sgi) && !defined(PTY_DONE)
#define PTY_DONE
int
OpenPTY(ttyn)
SV *ttyn;
{
  int f;
  char *name; 
  sigret_t (*sigcld)_(SIGPROTOARG);

  /*
   * SIGCHLD set to SIG_DFL for _getpty() because it may fork() and
   * exec() /usr/adm/mkpts
   */
  sigcld = signal(SIGCHLD, SIG_DFL);
  name = _getpty(&f, O_RDWR | O_NONBLOCK, 0600, 0);
  signal(SIGCHLD, sigcld);

  if (name == 0)
    return -1;
  initpty(f);
  sv_setpv(ttyn,name);
  return f;
}
#endif

/***************************************************************/

#if defined(MIPS) && defined(HAVE_DEV_PTC) && !defined(PTY_DONE)
#define PTY_DONE
int
OpenPTY(ttyn)
SV *ttyn;
{
  register int f;
  struct stat buf;
  char PtyName[32], TtyName[32];
   
  strcpy(PtyName, "/dev/ptc");
  if ((f = open(PtyName, O_RDWR | O_NONBLOCK)) < 0)
    return -1;
  if (fstat(f, &buf) < 0)
    {
      close(f);
      return -1;
    }
  sprintf(TtyName, "/dev/ttyq%d", minor(buf.st_rdev));
  initpty(f);
  sv_setpv(ttyn,TtyName);
  return f;
}
#endif

/***************************************************************/

#if defined(SVR4) && !defined(PTY_DONE)
#define PTY_DONE
int
OpenPTY(ttyn)
SV *ttyn;
{
  register int f;
  char *m, *ptsname();
  int unlockpt _((int)), grantpt _((int));
  sigret_t (*sigcld)_(SIGPROTOARG);
  char TtyName[32];

  if ((f = open("/dev/ptmx", O_RDWR)) == -1)
    return -1;

  /*
   * SIGCHLD set to SIG_DFL for grantpt() because it fork()s and
   * exec()s pt_chmod
   */
  sigcld = signal(SIGCHLD, SIG_DFL);
  if ((m = ptsname(f)) == NULL || grantpt(f) || unlockpt(f))
    {
      signal(SIGCHLD, sigcld);
      close(f);
      return -1;
    } 
  signal(SIGCHLD, sigcld);
  strncpy(TtyName, m, sizeof(TtyName));
  initpty(f);
  sv_setpv(ttyn,TtyName);
  return f;
}
#endif

/***************************************************************/

#if defined(_AIX) && defined(HAVE_DEV_PTC) && !defined(PTY_DONE)
#define PTY_DONE

#ifdef _IBMR2
int aixhack = -1;
#endif

int
OpenPTY(ttyn)
SV *ttyn;
{
  register int f;
  char PtyName[32], TtyName[32];

  /* a dumb looking loop replaced by mycrofts code: */
  strcpy (PtyName, "/dev/ptc");
  if ((f = open (PtyName, O_RDWR)) < 0)
    return -1;
  strncpy(TtyName, ttyname(f), sizeof(TtyName));
  if (eff_uid && access(TtyName, R_OK | W_OK))
    {
      close(f);
      return -1;
    }
  initpty(f);
# ifdef _IBMR2
  if (aixhack >= 0)
    close(aixhack);
  if ((aixhack = open(TtyName, O_RDWR | O_NOCTTY)) < 0)
    {
      close(f);
      return -1;
    }
# endif
  sv_setpv(ttyn,TtyName);
  return f;
}
#endif

/***************************************************************/

#ifndef PTY_DONE
int
OpenPTY(ttyn)
SV *ttyn;
{
  register char *p, *q, *l, *d;
  register int f;
  char PtyName[32], TtyName[32];

  strcpy(PtyName, PtyProto);
  strcpy(TtyName, TtyProto);
  for (p = PtyName; *p != 'X'; p++)
    ;
  for (q = TtyName; *q != 'X'; q++)
    ;
  for (l = PTYRANGE0; (*p = *l) != '\0'; l++)
    {
      for (d = PTYRANGE1; (p[1] = *d) != '\0'; d++)
	{
	  if ((f = open(PtyName, O_RDWR)) == -1)
	    continue;
	  q[0] = *l;
	  q[1] = *d;
	  if (eff_uid && access(TtyName, R_OK | W_OK))
	    {
	      close(f);
	      continue;
	    }
#if defined(sun) && defined(TIOCGPGRP) && !defined(SUNOS3)
	  /* Hack to ensure that the slave side of the pty is
	   * unused. May not work in anything other than SunOS4.1
	   */
	    {
	      int pgrp;

	      /* tcgetpgrp does not work (uses TIOCGETPGRP)! */
	      if (ioctl(f, TIOCGPGRP, (char *)&pgrp) != -1 || errno != EIO)
		{
		  close(f);
		  continue;
		}
	    }
#endif
	  initpty(f);
	  sv_setpv(ttyn,TtyName);
	  return f;
	}
    }
  return -1;
}
#endif

int
InitSlave(f,ttyn)
InOutStream f;
char *ttyn;
{
#if defined(SVR4) && !defined(sgi)
 int fd = PerlIO_fileno(f);

 if (ioctl(fd, I_PUSH, "ptem"))
  croak("Cannot I_PUSH ptem %s %s", ttyn, strerror(errno));
 if (ioctl(fd, I_PUSH, "ldterm"))
  croak("Cannot I_PUSH ldterm %s %s", ttyn, strerror(errno));
 if (ioctl(fd, I_PUSH, "ttcompat"))
  croak("Cannot I_PUSH ttcompat %s %s", ttyn, strerror(errno));
#endif
 return 1;
}

MODULE = IO::Pty	PACKAGE = IO::Pty

int
OpenPTY(ttyn)
SV *	ttyn

MODULE = IO::Tty	PACKAGE = IO::Tty

int
InitSlave(f,ttyn)
InOutStream f
char *	ttyn

char *
ttyname(handle)
	InOutStream handle
    CODE:
#ifdef HAS_TTYNAME
	if(handle)
	    RETVAL = ttyname(PerlIO_fileno(handle));
	else {
	    RETVAL = Nullch;
	    errno = EINVAL;
	}
#else
	NOT_HERE("IO::Tty::ttyname", Nullch);
#endif
    OUTPUT:
	RETVAL

BOOT:
 {
  eff_uid = geteuid();
 }
