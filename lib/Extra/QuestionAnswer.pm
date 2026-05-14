package Extra::QuestionAnswer;

use strict;
use Exporter qw(import);

our @EXPORT = qw(encryptHTML decryptHTML);

my @FULLWIDTH_DIGIT = (
    '&#65296;',
    '&#65297;',
    '&#65298;',
    '&#65299;',
    '&#65300;',
    '&#65301;',
    '&#65302;',
    '&#65303;',
    '&#65304;',
    '&#65305;',
);

sub encryptHTML {
    my $question = shift;
    $question = '' unless defined $question;

    my $length = length $question;
    my $half = int($length / 2 + 0.5);
    my $transformed = '';

    for (my $i = 0; $i <= $half; $i++) {
        $transformed .= substr($question, $i, 1);
        $transformed .= substr($question, $i + $half, 1);
    }

    $transformed = substr($transformed, 0, $length);
    $transformed =~ s/`/'/g;
    $transformed =~ s/\@\@/\\\\/g;
    $transformed =~ s/qg/\r\n/g;

    my $answer = '';
    for my $char (split //, $transformed) {
        next unless $char =~ /\A[0-9]\z/;
        $answer .= $FULLWIDTH_DIGIT[$char];
    }

    return $answer;
}

sub decryptHTML {
    my $str = shift;
    $str = '' unless defined $str;
    my $k = shift || unescape('%0D%0A');

    $str .= ' ' if (length($str) % 2);
    $str =~ s/$k/qg/g;
    $str =~ s/\\/@@/g;
    $str =~ s/'/`/g;

    my @chars = split //, $str;
    my $half = length($str) / 2;

    return join('', map { $chars[2 * $_] } (0 .. ($half - 1))) .
        join('', map { $chars[2 * $_ + 1] } (0 .. ($half - 1)));
}

sub unescape {
    my $str = shift;
    $str =~ s/%([0-9A-F][0-9A-F])/pack('H2', $1)/eg;
    return $str;
}

1;
