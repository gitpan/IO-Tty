use ExtUtils::MakeMaker;

use Config qw(%Config);
use IO::File;
$|=1; # to see output immediately

#
# Now some poking around in /dev to see what we can find
#

my @define;
my @libs;

push @define, qw(-DHAVE_CYGWIN -DHAVE_DEV_PTMX)
  if ($^O =~ m/cygwin/i);

push @define, '-DHAVE_DEV_PTMX'
  if (-c '/dev/ptmx');

push @define, '-DHAVE_DEV_PTYM_CLONE'
  if (-c '/dev/ptym/clone');

push @define, '-DHAVE_DEV_PTC'
  if (-c "/dev/ptc");

push @define, '-DHAVE_DEV_PTMX_BSD'
  if (-c "/dev/ptmx_bsd");

push @define, '-DHAVE_DEV_PTYM'
  if (-d "/dev/ptym" and -d "/dev/pty");

# config tests go to a separate dir
unless( mkdir 'conf', 0777 ) {
  my $e = $!;
  die "mkdir: $e" unless -d 'conf';
}

use Cwd qw(getcwd);
my $dir = getcwd;
chdir('conf') or die "chdir: $!";

open(TST,">compilerok.c") or die "open: $!";
print TST <<'ESQ';
int main () { return 0; }
ESQ
close(TST);

if (system("$Config{'cc'} $Config{'cppflags'} compilerok.c")) {
  die <<"EDQ";

ERROR: cannot run the configured compiler $Config{'cc'}

EDQ
}

# checking for various functions

my %funcs = (ttyname   => "",
	     openpty   => "-lutil",
	     _getpty   => "",
	     strlcpy   => "",
	     sigaction => "",
	     grantpt   => "",
	     unlockpt  => "",
	     getpt     => "",
	     ptsname   => "",
	    );

foreach my $f (keys %funcs) {
  open(TST,">conftest.c") or die "open: $!";
  print TST <<"ESQ";
/* System header to define __stub macros and hopefully few prototypes,
    which can conflict with char $ac_func (); below.  */
#include <assert.h>
/* Override any gcc2 internal prototype to avoid an error.  */
#ifdef __cplusplus
extern "C"
#endif
/* We use char because int might match the return type of a gcc2
   builtin and then its argument prototype would still apply.  */
char $f ();
char (*f) ();

#ifdef F77_DUMMY_MAIN
#  ifdef __cplusplus
     extern "C"
#  endif
   int F77_DUMMY_MAIN() { return 1; }
#endif
int
main ()
{
/* The GNU C library defines this for functions which it implements
    to always fail with ENOSYS.  Some functions are actually named
    something starting with __ and the normal name is an alias.  */
#if defined (__stub_$f) || defined (__stub___$f)
choke me
#else
f = $f;
#endif

  ;
  return 0;
}
ESQ

  close(TST);
  print "Looking for $f()... ";
  if (system("$Config{'cc'} $Config{'cppflags'} $funcs{$f} conftest.c >/dev/null 2>&1")) {
    print "not found.\n";
  } else {
    push(@define, "-DHAVE_\U$f");
    push @libs, $funcs{$f} if $funcs{$f};
    print "found.\n";
  }
}

# find various headerfiles

@headers = qw(libutil.h util.h pty.h sys/stropts.h);

foreach my $h (@headers) {
  open(TST,">headtest.c") or die "open: $!";
  print TST <<"ESQ";
#include <sys/types.h>
#include <$h>
int main () { return 0; }
ESQ
  close(TST);
  print "Looking for $h... ";
  if(system("$Config{'cc'} $Config{'cppflags'} headtest.c > /dev/null 2>&1")) {
    print "not found.\n"
  }
  else {
    $h =~ s/\W/_/g;
    push(@define, "-DHAVE_\U$h");
    print "found.\n";
  }
}

chdir($dir) or die "chdir: $!";

open(SUB,">xssubs.c") or die "open: $!";

print SUB qq{sv_setpv(config, "@define");\n};

foreach (qw(B0 B110 B115200 B1200 B134 B150 B153600 B1800 B19200 B200
	    B230400 B2400 B300 B307200 B38400 B460800 B4800 B50 B57600
	    B600 B75 B76800 B9600 BRKINT BS0 BS1 BSDLY CBAUD CBAUDEXT
	    CBRK CCTS_OFLOW CDEL CDSUSP CEOF CEOL CEOL2 CEOT CERASE
	    CESC CFLUSH CIBAUD CIBAUDEXT CINTR CKILL CLNEXT CLOCAL
	    CNSWTCH CNUL CQUIT CR0 CR1 CR2 CR3 CRDLY CREAD CRPRNT
	    CRTSCTS CRTSXOFF CRTS_IFLOW CS5 CS6 CS7 CS8 CSIZE CSTART
	    CSTOP CSTOPB CSUSP CSWTCH CWERASE DEFECHO DIOC DIOCGETP
	    DIOCSETP DOSMODE ECHO ECHOCTL ECHOE ECHOK ECHOKE ECHONL
	    ECHOPRT EXTA EXTB FF0 FF1 FFDLY FIORDCHK FLUSHO HUPCL
	    ICANON ICRNL IEXTEN IGNBRK IGNCR IGNPAR IMAXBEL INLCR
	    INPCK ISIG ISTRIP IUCLC IXANY IXOFF IXON KBENABLED LDCHG
	    LDCLOSE LDDMAP LDEMAP LDGETT LDGMAP LDIOC LDNMAP LDOPEN
	    LDSETT LDSMAP LOBLK NCCS NL0 NL1 NLDLY NOFLSH OCRNL OFDEL
	    OFILL OLCUC ONLCR ONLRET ONOCR OPOST PAGEOUT PARENB PAREXT
	    PARMRK PARODD PENDIN RCV1EN RTS_TOG TAB0 TAB1 TAB2 TAB3
	    TABDLY TCDSET TCFLSH TCGETA TCGETS TCIFLUSH TCIOFF
	    TCIOFLUSH TCION TCOFLUSH TCOOFF TCOON TCSADRAIN TCSAFLUSH
	    TCSANOW TCSBRK TCSETA TCSETAF TCSETAW TCSETCTTY TCSETS TCSETSF
	    TCSETSW TCXONC TERM_D40 TERM_D42 TERM_H45 TERM_NONE
	    TERM_TEC TERM_TEX TERM_V10 TERM_V61 TIOCCBRK TIOCCDTR
	    TIOCCONS TIOCEXCL TIOCFLUSH TIOCGETC TIOCGETD TIOCGETP
	    TIOCGLTC TIOCGPGRP TIOCGSID TIOCGSOFTCAR TIOCGWINSZ
	    TIOCHPCL TIOCKBOF TIOCKBON TIOCLBIC TIOCLBIS TIOCLGET
	    TIOCLSET TIOCMBIC TIOCMBIS TIOCMGET TIOCMSET TIOCM_CAR
	    TIOCM_CD TIOCM_CTS TIOCM_DSR TIOCM_DTR TIOCM_LE TIOCM_RI
	    TIOCM_RNG TIOCM_RTS TIOCM_SR TIOCM_ST TIOCNOTTY TIOCNXCL
	    TIOCOUTQ TIOCREMOTE TIOCSBRK TIOCSCTTY TIOCSDTR TIOCSETC
	    TIOCSETD TIOCSETN TIOCSETP TIOCSIGNAL TIOCSLTC TIOCSPGRP
	    TIOCSSID TIOCSSOFTCAR TIOCSTART TIOCSTI TIOCSTOP
	    TIOCSWINSZ TM_ANL TM_CECHO TM_CINVIS TM_LCF TM_NONE TM_SET
	    TM_SNL TOSTOP VCEOF VCEOL VDISCARD VDSUSP VEOF VEOL VEOL2
	    VERASE VINTR VKILL VLNEXT VMIN VQUIT VREPRINT VSTART VSTOP
	    VSUSP VSWTCH VT0 VT1 VTDLY VTIME VWERASE WRAP XCASE XCLUDE
	    XMT1EN XTABS)) {

  print SUB <<"EDQ";
#ifdef $_
newCONSTSUB(stash, "$_", newSViv($_));
#else
newCONSTSUB(stash, "$_", &PL_sv_undef);
#endif
EDQ
}
close(SUB);

my @ppd;

if ($] >= 5.00503) {
  @ppd = (
    AUTHOR    => 'Graham Barr <gbarr@pobox.com>, Roland Giersig <RGiersig@cpan.org',
    ABSTRACT  => 'Pseudo tty\'s and constants'
  );
}

print "DEFINE = @define\n";

WriteMakefile(
    'NAME'	    => 'IO::Tty',
    'VERSION_FROM'  => "Tty.pm",
    'DEFINE'	    => join(" ", @define),
    'LIBS'          => join(" ", @libs),
    'clean'	    => {'FILES' => 'xssubs.c conf'},
    'MAP_TARGET'    => 'perltty',
    @ppd,
);

sub MY::postamble {

  return '' unless $] >= 5.00503;

<<'ESQ';

dist : ppd

ESQ
}

