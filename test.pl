
use strict;
$^W = 1; # enable warnings
use Test;
use blib;
use IO::Pty;
use IO::Tty qw(TIOCSCTTY TIOCNOTTY TCSETCTTY);
$IO::Tty::DEBUG = 1;

require POSIX;

my $Perl = $^X;

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

plan tests => 3;

# now for the echoback tests
print "Checking how your ptys handle large strings (may take a while)...\n";
{
  my $randstring = "fakjdf ijj845jtirg\r\n8e 4jy8 gfuoyhj\agt8h\0x00 gues98\0xFF 45th guoa\beh gt98hae 45t8u ha8rhg ue4ht 8eh tgo8he4 t8 gfj aoingf9a8hgf uain dgkjadshft+uehgfusand987vgh afugh 8*h 98H 978H 7HG zG 86G (&g (O/g &(GF(/EG F78G F87SG F(/G F(/a sldjkf ha\@j<ksdhf jk>~|ahsd fjkh asdHJKGDSGFKLZSTRJKSGOSJDFKGHSHGDFJGDSFJKHGSDFHJGSDK1%&FJGSDGFSHJDGFljkhf lakjs(dh fkjahs djfk hasjkdh fjklahs dfkjhasdjkf hajksdh fkjah sdjf)\$/§&k hasjkdh fkjhuerhtuwe htui eruth ZI AHD BIZA Di7GH )/g98 9 97 86tr(& TA&(t 6t &T 75r 5\$R%/4r76 5&/% R79 5 )/&";
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
    my $cnt = 0;
    while(1) { 
      my $ret = sysread($slave, $c, 1);
      warn "sysread(): $!" unless defined $ret;
      die "EOF at byte $cnt" unless $ret;
      $cnt++;
      $ret = syswrite($slave, ~$c, 1);
      warn "syswrite(): $!" unless defined $ret;
    }
  }
  close TO_PARENT;
  $master->close_slave();
  my $dummy;
  my $stat = sysread(FROM_CHILD, $dummy, 1);
  die "Cannot sync with child: $!" if not $stat;
  close FROM_CHILD;

  # parent sends down some strings and expects to get them back inverted
  my $maxlen = 0;
  foreach my $len (1 .. length($randstring)) {
#    print STDERR "$len   \r";
    my $s = substr($randstring, 0, $len);
    my $buf;
    my $ret = "";
    my $sendbuf = $s;
    $SIG{ALRM} = sub { die "TIMEOUT "; };
    eval {
      alarm(10);
      while ($sendbuf or length($ret) < length($s)) {
	if ($sendbuf) {
	  my $sent = syswrite($master, $sendbuf, length($sendbuf));
	  die "syswrite() failed: $!" unless defined $sent;
	  $sendbuf = substr($sendbuf, $sent);
	}
	$buf = "";
	my $read = sysread($master, $buf, length($s));
	die "Read error: $!" if not defined $read;
	warn "Got EOF" if not $read;
	die "Didn't get any bytes" if not $buf;
	$ret .= $buf;
      }
      alarm(0);
    };
    last if ($@);

    if ($ret eq ~$s) {
      $maxlen = $len;
    } else {
      if (length($s) == length($ret)) {
	warn "Got back a wrong string with the right length ".length($ret)."\n";
      } else {
	warn "Got back a wrong string with the wrong length ".length($ret).
	  " (instead of ".length($s).")\n";
      }
      ok(0);
      last;
    }
  }
  if ($maxlen < length($randstring)) {
    warn <<"_EOT_";

WARNING: your raw ptys block when sending more than $maxlen bytes!
This may cause problems under special scenarios, but you probably
will never encounter that problem.

_EOT_
  }
  ok($maxlen >= 200);
  close($master);
  sleep(1);
  kill TERM => $pid;
}


print "Checking if child gets pty as controlling terminal...\n";
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
  die "Cannot sync with child: $!" if not $stat;
  close FROM_CHILD;

  my ($s, $chunk);
  $SIG{ALRM} = sub { ok(0); die "Timeout ($s)"; };
  alarm(10);

  sysread($master, $s, 100) or die "sysread() failed: $!";
  ok($s =~ m/gimme.*:/);

  print $master "seems OK!\n";

  # collect all responses
  my $ret;
  while ($ret = sysread($master, $chunk, 100)) {
    $s .= $chunk;
  }
  print $s;
  warn "sysread(EOF): $!" unless defined $ret;
  ok($s =~ m/back on STDOUT: SEEMS OK!/);
  alarm(0);
  kill TERM => $pid;
}


