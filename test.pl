
use strict;
use Test;
use blib;
use IO::Pty;

require POSIX;

my $Perl = $^X;

my @Strings =
  (
   "ÄÜÖ",
   "The quick brown fox jumped over the lazy dog.\n",
   " fakjdf ijj845jtirg8e 4jy8 gfuoyhjgt8h gues9845th guoaeh gt98hae 45t8u ha8rhg ue4ht 8eh tgo8he4 t8 gfj aoingf9a8hgf uain dgkjadshftuehgfusand987vgh afugh 8h 98H 978H 7HG zG 86G (&g (O/g &(GF(/EG F78G F87SG F(/G F(/a sldjkf hajksdhf jkahsd fjkh asdljkhf lakjsdh fkjahs djfk hasjkdh fjklahs dfkjhasdjkf hajksdh fkjah sdjfk hasjkdh fkjashd fjkha sdjkfhehurthuerhtuwe htui eruth\r\n",
   "\r\r\n\r\b\n\r\0x00\0xFF",
  );

plan tests => @Strings*2;

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

my $master = new IO::Pty;
print "isatty(\$master): ", POSIX::isatty($master)? "YES\n": "NO\n";

eval { set_raw_pty($master); };
warn "warning: set_raw_pty(\$master): $@\n" if $@;

my $slave = $master->slave();
print "isatty(\$slave): ", POSIX::isatty($slave)? "YES\n": "NO\n";

eval { set_raw_pty($slave); };
warn "warning: set_raw_pty(\$slave): $@\n" if $@;

$SIG{ALRM} = sub { die "Timeout"; };

my $pid = fork;
die "Cannot fork: $!" if ($pid < 0);

if ($pid) {
  close($slave);
  # parent sends down some strings and expects to get them back inverted
  foreach my $s (@Strings) {
    my ($ret, $buf);
    syswrite($master, $s, length($s));
    alarm(20);
    while (length($ret) < length($s)) {
      sysread($master, $buf, length($s))
	or die "Couldn't read anything: $!";
      $ret .= $buf;
    }
    alarm(0);
    ok(length($s), length($ret));
    ok($ret, ~$s);
  }
  kill TERM => $pid;
} else {
  # child negates all characters sent down
  POSIX::setsid();
  close($master);
  open(STDIN, "<&".fileno($slave)) || die "Cannot open STDIN: $!";
  open(STDOUT,">&".fileno($slave)) || die "Cannot open STDOUT: $!";
  open(STDERR,">&STDOUT")        || die "Cannot open STDERR: $!";
  close($slave);
  exec($Perl, "-e", 'while(1){sysread(STDIN,$c,1);syswrite(STDOUT,~$c,1)}');
  die "Cannot exec $Perl: $!";
}
