
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

plan tests => @Strings*2 + 2;

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

# now for the echoback tests
{
  my $master = new IO::Pty;
  print "isatty(\$master): ", POSIX::isatty($master)? "YES\n": "NO\n";
#  if (POSIX::isatty($master)) {
#    eval { set_raw_pty($master); };
#    warn "warning: set_raw_pty(\$master): $@\n" if $@;
#  }

  pipe(FROM_CHILD, TO_PARENT)
    or die "Cannot create pipe: $!";
  my $pid = fork();
  die "Cannot fork" if not defined $pid;
  unless ($pid) {
    # child sends back everything inverted
    my $c;
    my $slave = $master->slave();
    close $master;
    eval { set_raw_pty($slave); };
    warn "warning: set_raw_pty(\$slave): $@\n" if $@;
    close FROM_CHILD;
    print TO_PARENT "\n";
    close TO_PARENT;
    while(1) { 
      sysread($slave, $c, 1);
      print ".";
      syswrite($slave, ~$c, 1);
    }
  }
  close TO_PARENT;
  $master->close_slave();
  my $dummy;
  my $stat = sysread(FROM_CHILD, $dummy, 1);
  die "Cannot sync with child: $!" if not defined $stat;
  close FROM_CHILD;

  # parent sends down some strings and expects to get them back inverted
  foreach my $s (@Strings) {
    my $buf;
    my $ret = "";
    syswrite($master, $s, length($s));
    $SIG{ALRM} = sub { ok(0); die "Timeout"; };
    alarm(10);
    while (length($ret) < length($s)) {
      $buf = "";
      my $read = sysread($master, $buf, length($s));
      die "Read error: $!" if not defined $read;
      warn "Got EOF" if not $read;
      die "Didn't get any bytes" if not $buf;
      $ret .= $buf;
    }
    alarm(0);
    print "\n";
    ok(length($s), length($ret));
    ok($ret, ~$s);
  }
  kill TERM => $pid;
}

# test if child gets pty as controlling terminal
{
  my $master = new IO::Pty;

  pipe(FROM_CHILD, TO_PARENT)
    or die "Cannot create pipe: $!";
  my $pid = fork();
  die "Cannot fork" if not defined $pid;
  unless ($pid) {
    # child 
    $master->make_slave_controlling_terminal();
    my $slave = $master->slave();
    close $master;
    close FROM_CHILD;
    print TO_PARENT "\n";
    close TO_PARENT;
    open(TTY, "+>/dev/tty") or die "no controlling terminal";
    autoflush TTY 1;
    print TTY "gimme on /dev/tty: ";
    my $s = <TTY>;
    chomp $s;
    print $slave "back on STDOUT: \U$s\n";
    close TTY; close $slave;
    exit 0;
  }

  close TO_PARENT;
  $master->close_slave();
  my $dummy;
  my $stat = sysread(FROM_CHILD, $dummy, 1);
  die "Cannot sync with child: $!" if not defined $stat;
  close FROM_CHILD;

  my ($s, $chunk);
  $SIG{ALRM} = sub { ok(0); die "Timeout ($s)"; };
  alarm(10);

  sysread($master, $s, 100) or die "sysread() failed: $!";
  ok($s =~ m/gimme.*:/);

  print $master "seems OK!\n";

  # collect all responses
  while (sysread($master, $chunk, 100)) {
    $s .= $chunk;
  }
  print $s;
  ok($s =~ m/back on STDOUT: SEEMS OK!/);
  alarm(0);
  kill TERM => $pid;
}


