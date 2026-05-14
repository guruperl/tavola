package Extra::HTMLCrypt;

use strict;
#use encoding 'utf8';
use vars qw(@ISA @EXPORT $VERSION);

use Exporter;
$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(complicated get_escape_html get_normal_html get_escape_piece);

my $randompw  = sub {
  my $len = shift || 8;
  my @chars = ('a'..'z', '0'..'9');
  my $num = scalar @chars;

  return join('', map {$chars[$num * rand()]} (1..$len));
};

sub complicated {
  my $digits = shift;

  #my @g_h = qw(0 1 2 3 4 5 6 7 8 9);
  #my @g_h = qw(０ １ ２ ３ ４ ５ ６ ７ ８ ９);
  my @g_h = qw(&#65296; &#65297; &#65298; &#65299; &#65300; &#65301; &#65302; &#65303; &#65304; &#65305;);

  my $show = "";
  for my $item (map {$g_h[$_]} split(//, $digits)) {
    my $m = int(3*rand());
    for (0..$m) {
      my $str = $randompw->(int(5*rand())+1);
      $show .= "<span class=_g$str></span>";
    }
    my $span = $randompw->(int(5*rand())+1);
    $show .= "<span class=_g$span>$item</span>";
    $m = int(3*rand());
    for (0..$m) {
      my $str = $randompw->(int(5*rand())+1);
      $show .= "<span class=_g$str></span>";
    }
  }

  return get_escape_piece($show);
}

sub get_escape_piece {
  my $body = shift;
  $body = encrypt1($body);

  my $js = decrypt1_js();
  $js = escape($js);

  return "<script>lo='$body';</script><script>eval(unescape('$js'));</script>";
}

sub get_escape_html {
  my $body = shift;
  my $extra = shift;
  $body = encrypt1($body, shift);

  my $js = decrypt1_js();
  $js = escape($js);

  return
"<html><head>$extra<script>lo='$body';</script><script>eval(unescape('$js'));</script></head><body></body></html>\n";
}

sub get_normal_html {
  my $body = shift;
  my $extra = shift;
  my $marker = shift; # this should use default! others are wrong. sorry
  $body = encrypt1($body, $marker);

  my $js = decrypt1_js();

  return
"<html><head>$extra<script>lo='$body';</script><script>$js;</script></head><body></body></html>\n";
}

sub escape {
  my $str = join '',  map {uc sprintf("%%%02x",ord($_))} (split '', shift);
  return $str;
}

sub unescape {
  my $str = shift;

  $str =~ s/%([0-9A-F][0-9A-F])/pack("H2", $1)/eg;
  return $str;
}
 
sub encrypt1 {
  my $str = shift;
  my $k = shift || unescape("%0D%0A");

  $str .= ' ' if (length($str) % 2);

  $str =~ s/$k/qg/g;
  $str =~ s/\\/@@/g;
  $str =~ s/'/`/g;

  my @chars = split '', $str;
  my $half = length($str)/2;

  my $newstr = join('', map {$chars[2*$_]} (0 .. ($half-1))).
	join('', map {$chars[2*$_+1]} (0 .. ($half-1)));
  return $newstr;
}

sub decrypt1 {
  my $str = shift;

  my @chars = split '', $str;
  my $half = length($str)/2;

  my $newstr = join '', map {$chars[$_].$chars[$_+$half]} (0 .. ($half-1));
  $newstr =~ s/`/'/g;
  $newstr =~ s/@@/\\/g;
  my $k = unescape("%0D%0A");
  $newstr =~ s/qg/$k/g;

  return $newstr;
}
 
=pod
sub decrypt1_js {
  return qq~k = unescape("%0D%0A");
  n9= pfm(lo);
  document.write(n9);

  function pfm(s) {
    var un = "";
    l = s.length;
    oh= Math.round(l/2);
    for(i=0; i<=oh; i++) {
      a = s.charAt(i);
      b = s.charAt(i+oh);
      c = a+b;
      un= un+c;
    };

    J = un.substr(0,l);
    J = J.replace(/`/g,"'");
    J = J.replace(/@@/g,"\\\\");
    f = /qg/g;
    J = J.replace(f,k);
    return J;
  }~;
}
=cut

sub decrypt1_js {
  return qq~k=unescape("%0D%0A");n9=pfm(lo);document.write(n9);function pfm(s){var un="";l=s.length;oh=Math.round(l/2);for(i=0;i<=oh;i++){a=s.charAt(i);b=s.charAt(i+oh);c=a+b;un=un+c;};J=un.substr(0,l);J=J.replace(/`/g,"'");J=J.replace(/@@/g,"\\\\");f=/qg/g;J=J.replace(f,k);return J;}~;
}

1;
__END__
#!/usr/bin/perl

use strict;
use encoding 'utf8';
use Common::ComplicateHTML;

my $fn = shift || '__a.htm__';
my $extra = '<meta http-equiv="content-type" content="text/html;charset=utf-8">';

local *A;
open(A, "<:utf8", $fn) || die $!;
my $orig;
while (<A>) {
chomp;
$orig .= $_;
}
close(A);

my $end = get_escape_html($orig, $extra);
open(A, ">__b.htm") || die $!;
binmode A, ":utf8";
print A $end;
close(A);

exit(0)
