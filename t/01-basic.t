#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
plan 'no_plan';

use Text::Pivot;

my ( $t0, $p0, $p1, $p2 );

sub o0 ($) {
    my $p0 = $_[0];
    diag $p0->start, " ", $p0->head, " ", $p0->tail, " m ", $p0->mhead, " ", $p0->mtail;
}

sub opr ($) {
    my $p0 = $_[0];
    diag 'pr: [', $p0->preceding, ']';
}

sub ore ($) {
    my $p0 = $_[0];
    diag 're: [', $p0->remaining, ']';
}

my $data = <<_END_;

{
    abcdefghijklmnopqrstuvwxyz

qwerty
-
1 2 3 4 5 5 6 7 8 9     

    xyzzy

}

_END_

$p0 = Text::Pivot->new( data => $data );
is( $p0->preceding, '' );
is( $p0->remaining, $data );

$p1 = $p0->find( qr/rty/ );
is( $p1->preceding, <<_END_ );

{
    abcdefghijklmnopqrstuvwxyz

_END_
is( $p1->remaining, <<_END_ );
-
1 2 3 4 5 5 6 7 8 9     

    xyzzy

}

_END_

$p2 = $p1->find( qr/ 5 (6) 7 / );
is( $p2->preceding, <<_END_ );
-
_END_
is( $p2->remaining, <<_END_ );

    xyzzy

}

_END_
is( $p2->match( 0 ), 6 );
is( $p2->found, ' 5 6 7 ' );

$p0 = $p2;
$p0 = $p0->find( qr/}\n\n/ );
is( $p0->preceding, <<_END_ );

    xyzzy

_END_
is( $p0->remaining, '' );
