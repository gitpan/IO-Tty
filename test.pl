
use strict;
$^W = 1; # enable warnings
use Test;
use blib;
use IO::Pty;
use IO::Tty qw(TIOCSCTTY TIOCCONS TIOCNOTTY TCSETCTTY);

require POSIX;

my $Perl = $^X;

my @Strings =
  (
   "ÄÜÖ",
   "The quick brown fox jumps over the lazy dog.\n",
   " fakjdf ijj845jtirg8e 4jy8 gfuoyhjgt8h gues9845th guoaeh gt98hae 45t8u ha8rhg ue4ht 8eh tgo8he4 t8 gfj aoingf9a8hgf uain dgkjadshftuehgfusand987vgh afugh 8h 98H 978H 7HG zG 86G (&g (O/g &(GF(/EG F78G F87SG F(/G F(/a sli eruth\r\n",
   "\r\r\n\r\b\n\r\0x00\0xFF",
  );

plan tests => @Strings*2 + 4;

sub set_raw_pty($) {
  my $ttyno = fileno(shift);
  my $termios = new POSIX::Termios;
  $termios->getattr($ttyno) or die "getattr: $!";
  $termios->setiflag(0);
  $termios->setoflag(0);
  $termios->setlflag(0);
  $termios->setcc(&POSIX::VMIN, 1);
  $termios->setcc(&POSIX::VTIME, 0);
  $termios->setattr($ttyno, &POSIX::TCSANOW) or die "setattr: $!";
}

print "Configuration: $IO::Tty::CONFIG\n";
print "Checking for appropriate ioctls: ";
print "TIOCNOTTY " if defined TIOCNOTTY;
print "TIOCSCTTY " if defined TIOCSCTTY;
print "TCSETCTTY " if defined TCSETCTTY;
print "\n";

# first check if we can detect a spawn error
{
  $! = 0;
  $SIG{ALRM} = sub { ok(0); die "Timeout"; };
  alarm(10);
  my $pty = IO::Pty->spawn("unknown_program_test_IGNORE_THIS_ERROR_ahat44535jtrbni43uh5");
  alarm(0);
  ok(not defined $pty);
  ok($!);
}

# now for the echoback tests
{
  my $master = new IO::Pty;
  print "isatty(\$master): ", POSIX::isatty($master)? "YES\n": "NO\n";

  if (POSIX::isatty($master)) {
    eval { set_raw_pty($master); };
    warn "warning: set_raw_pty(\$master): $@\n" if $@;
  }

  my $slave = $master->slave();
  print "isatty(\$slave): ", POSIX::isatty($slave)? "YES\n": "NO\n";

  if (POSIX::isatty($slave)) {
    eval { set_raw_pty($slave); };
    warn "warning: set_raw_pty(\$slave): $@\n" if $@;
  }

  $master->spawn($Perl, "-e", 'while(1){sysread(STDIN,$c,1);syswrite(STDOUT,~$c,1)}')
    or die "Cannot spawn test program";

  # parent sends down some strings and expects to get them back inverted
  foreach my $s (@Strings) {
    my $buf;
    my $ret = "";
    syswrite($master, $s, length($s));
    $SIG{ALRM} = sub { ok(0); die "Timeout"; };
    alarm(20);
    while (length($ret) < length($s)) {
      $buf = "";
      my $read = sysread($master, $buf, length($s));
      die "Read error: $!" if not defined $read;
      warn "Got EOF" if not $read;
      die "Didn't get any bytes" if not $buf;
      $ret .= $buf;
    }
    alarm(0);
    ok(length($s), length($ret));
    ok($ret, ~$s);
  }
  kill TERM => $master->slave_pid;
}

# test if child gets pty as controlling terminal
{
  my $child = IO::Pty->spawn ($Perl . q{ -MIO::Handle -e 'open(TTY, "+>/dev/tty") or die "no controlling terminal"; autoflush TTY 1; print TTY "gimme on /dev/tty: "; $s = <TTY>; chomp $s; print "back on STDOUT: \U$s\n"; close TTY; close STDOUT; close STDERR; exit 0;'}) # })
    or die "Cannot spawn $Perl: $!\n";

  my ($s, $chunk);
  $SIG{ALRM} = sub { ok(0); die "Timeout ($s)"; };
  alarm(10);

  sysread($child, $s, 100) or die "sysread() failed: $!";
  ok($s =~ m/gimme.*:/);

  print $child "seems OK!\n";

  # collect all responses
  while (sysread($child, $chunk, 100)) {
    $s .= $chunk;
  }
  print $s;
  ok($s =~ m/back on STDOUT: SEEMS OK!/);
  alarm(0);
}


