use ExtUtils::MakeMaker;

use Config qw(%Config &config_sh);
use IO::File;

#
# Grab things that perl's Configure has already discovered
#
#AutoConf::Define(sigret_t => $Config{'signal_t'});
#AutoConf::Define(SIGPROTOARG => '()');
#
# Now some poking around in /dev to see what we can find
#

my @define;

push(@define, '-DHAVE_DEV_PTC')
	 if (-e "/dev/ptc");

$pdir = (-d "/dev/ptym") ? "/dev/ptym" : "/dev";
@ptys = <$pdir/pty??>;
if (@ptys)
 {
  my %p0 = ();
  my %p1 = ();
  foreach (@ptys)
   {
    my ($x,$y) = /(.)(.)$/;
    $p0{$x}++;
    $p1{$y}++;
   }
  push(@define, '-DPTYRANGE0=\\"' . join('',sort(keys %p0)) . '\\"');
  push(@define, '-DPTYRANGE1=\\"' . join('',sort(keys %p1)) . '\\"');

  push(@define, '-DPTYTEMPLATE=\\"' . "$pdir/ptyXY" . '\\"');
 }


unless( mkdir 'conf', 0777 ) {
  my $e = $!;
  die "mkdir: $e" unless -d 'conf';
}

use Cwd qw(getcwd);
my $dir = getcwd;
chdir('conf') or die "chdir: $!";
open(TST,">tst.c") or die "open: $!";
print TST <<'ESQ';
extern char *ttyname(int);
int main () { (void)ttyname(0); return 0; }
ESQ
close(TST);
$|=1;
print "Looking for ttyname()....";
if( system($Config{'cc'},'tst.c')) {
  print <<EDQ;

I cannot seem to find ttyname() on your system

EDQ
}
else {
 push(@define, '-DHAS_TTYNAME');
 print "Found\n";
}

chdir($dir) or die "chdir: $!";

open(SUB,">xssubs.c") or die "open: $!";
foreach (qw(B0 B110 B115200 B1200 B134 B150 B153600 B1800 B19200 B200 B230400
	    B2400 B300 B307200 B38400 B460800 B4800 B50 B57600 B600 B75 B76800
	    B9600 BRKINT BS0 BS1 BSDLY CBAUD CBAUDEXT CBRK CCTS_OFLOW CDEL
	    CDSUSP CEOF CEOL CEOL2 CEOT CERASE CESC CFLUSH CIBAUD CIBAUDEXT
	    CINTR CKILL CLNEXT CLOCAL CNSWTCH CNUL CQUIT CR0 CR1 CR2 CR3 CRDLY
	    CREAD CRPRNT CRTSCTS CRTSXOFF CRTS_IFLOW CS5 CS6 CS7 CS8 CSIZE
	    CSTART CSTOP CSTOPB CSUSP CSWTCH CWERASE DEFECHO DIOC DIOCGETP
	    DIOCSETP DOSMODE ECHO ECHOCTL ECHOE ECHOK ECHOKE ECHONL ECHOPRT
	    EXTA EXTB FF0 FF1 FFDLY FIORDCHK FLUSHO HUPCL ICANON ICRNL IEXTEN
	    IGNBRK IGNCR IGNPAR IMAXBEL INLCR INPCK ISIG ISTRIP IUCLC IXANY
	    IXOFF IXON KBENABLED LDCHG LDCLOSE LDDMAP LDEMAP LDGETT LDGMAP
	    LDIOC LDNMAP LDOPEN LDSETT LDSMAP LOBLK NCCS NL0 NL1 NLDLY NOFLSH
	    OCRNL OFDEL OFILL OLCUC ONLCR ONLRET ONOCR OPOST PAGEOUT PARENB
	    PAREXT PARMRK PARODD PENDIN RCV1EN RTS_TOG TAB0 TAB1 TAB2 TAB3
	    TABDLY TCDSET TCFLSH TCGETA TCGETS TCIFLUSH TCIOFF TCIOFLUSH TCION
	    TCOFLUSH TCOOFF TCOON TCSADRAIN TCSAFLUSH TCSANOW TCSBRK TCSETA
	    TCSETAF TCSETAW TCSETS TCSETSF TCSETSW TCXONC TERM_D40 TERM_D42
	    TERM_H45 TERM_NONE TERM_TEC TERM_TEX TERM_V10 TERM_V61 TIOCCBRK
	    TIOCCDTR TIOCEXCL TIOCFLUSH TIOCGETC TIOCGETD TIOCGETP TIOCGLTC
	    TIOCGPGRP TIOCGSID TIOCGSOFTCAR TIOCGWINSZ TIOCHPCL TIOCKBOF
	    TIOCKBON TIOCLBIC TIOCLBIS TIOCLGET TIOCLSET TIOCMBIC TIOCMBIS
	    TIOCMGET TIOCMSET TIOCM_CAR TIOCM_CD TIOCM_CTS TIOCM_DSR TIOCM_DTR
	    TIOCM_LE TIOCM_RI TIOCM_RNG TIOCM_RTS TIOCM_SR TIOCM_ST TIOCNOTTY
	    TIOCNXCL TIOCOUTQ TIOCREMOTE TIOCSBRK TIOCSDTR TIOCSETC TIOCSETD
	    TIOCSETN TIOCSETP TIOCSIGNAL TIOCSLTC TIOCSPGRP TIOCSSID
	    TIOCSSOFTCAR TIOCSTART TIOCSTI TIOCSTOP TIOCSWINSZ TM_ANL TM_CECHO
	    TM_CINVIS TM_LCF TM_NONE TM_SET TM_SNL TOSTOP VCEOF VCEOL VDISCARD
	    VDSUSP VEOF VEOL VEOL2 VERASE VINTR VKILL VLNEXT VMIN VQUIT
	    VREPRINT VSTART VSTOP VSUSP VSWTCH VT0 VT1 VTDLY VTIME VWERASE WRAP
	    XCASE XCLUDE XMT1EN XTABS))
{
  print SUB <<"EDQ";
#ifdef $_
        newCONSTSUB(stash,"$_", newSViv($_));
#else
        av_push(export_fail, newSVpv("$_",${\(length)}));
#endif
EDQ
}
close(SUB);

my @ppd;

if ($] >= 5.00503) {
  @ppd = (
    AUTHOR    => 'Graham Barr <gbarr@pobox.com>',
    ABSTRACT  => 'Pseudo tty\'s and constants'
  );
}

WriteMakefile(
    'NAME'	    => 'IO::Tty',
    'VERSION_FROM'  => "Tty.pm",
    'DEFINE'	    => join(" ", @define), 
    'clean'	    => {'FILES' => 'xssubs.c conf *% *.html *.b[ac]k *.old *.orig *.rej a.out *log'},
    'MAP_TARGET'    => 'perltty',
    @ppd,
);

sub MY::postamble {

  return '' unless $] >= 5.00503;

<<'ESQ';

dist : ppd

ESQ
}

