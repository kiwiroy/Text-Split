package Text::Split;
# ABSTRACT: Text splitting with fine-grained control

=head1 SYNOPSIS

    $data = <<_END_
    # Xyzzy
    #   --- START 
        qwerty

            1 2 3 4 5 6
    8 9 10 The end

    # abcdefghi
            jklmnop
    _END_

    $split = Text::Split->new( data => ... )->find( qr/#\s*--- START/ )
    ( $split, $content ) = $split->find( qr/ The end/, slurp => '[]' )

C<$content> = 

    #   --- START 
        qwerty

            1 2 3 4 5 6
    8 9 10 The end

Alternatively, with

    ( $split, $content ) = $split->find( qr/ The end/, slurp => '()' )

C<$content> = 

        qwerty

            1 2 3 4 5 6

=head1 DESCRIPTION

With Text::Split, given a split in some text, you can access the text preceding and remaining the split. Consecutive splitting lets you slurp text from between splits (optionally including the text from the splits at either end).

More documentation coming soon.

=cut

use Any::Moose;

has data => qw/ reader data writer _data required 1 /;
has [qw/ start head tail mhead mtail /] => qw/ is rw required 1 isa Int default 0 /;
has _parent => qw/ is ro isa Maybe[Text::Split] init_arg parent /;

has found => qw/ is ro required 1 isa Str /, default => '';
has content => qw/ is ro required 1 isa Str /, default => '';
has _matched => qw/ init_arg matched is ro isa ArrayRef /, default => sub { [] };
sub matched { return @{ $_[0]->matched } }
has matcher => qw/ is ro required 1 /, default => undef;

has default => qw/  is ro lazy_build 1 isa HashRef /;
sub _build_default { {
    slurp => '[)',
} }

sub BUILD {
    my $self = shift;
    my $data = $self->data;
    $self->_data( \$data ) unless ref $data eq 'SCALAR';
}

sub _fhead ($$) {
    my ( $data, $from ) = @_;
    my $i0 = rindex $$data, "\n", $from;
    return $i0 + 1 unless -1 == $i0;
    return 0;
}

sub _ftail ($$) {
    my ( $data, $from ) = @_;
    my $i0 = index $$data, "\n", $from;
    return $i0 unless -1 == $i0;
    return -1 + length $$data;
}

sub parent {
    my $self = shift;
    if ( my $parent = $self->_parent ) { return $parent }
    return $self; # We are the base (root) split
}

sub is_root {
    my $self = shift;
    return ! $self->_parent;
}

sub _chomped2chomp ($) {
    my $slurp = $_[0];
    $slurp->{chomp} = delete $slurp->{chomped} if
        exists $slurp->{chomped} && not exists $slurp->{chomp};
}

sub _parse_slurp ($@) {
    my $slurp = shift;
    my %slurp = @_; # Can/will be overidden

    _chomped2chomp \%slurp;

    if ( ref $slurp eq 'HASH' ) {
        $slurp = { %$slurp };
        _chomped2chomp $slurp;
        %slurp = ( %slurp, %$slurp );
    }
    else {
        $slurp =~
            m{^
                ([\@\$])?
                ([\(\[])
                ([\)\]])
                (/)?
            }x or die "Invalid slurp pattern ($slurp)";

        $slurp{wantlist}    = $1 eq '@' ? 1 : 0 if $1;
        $slurp{slurpl}      = $2 eq '[' ? 1 : 0;
        $slurp{slurpr}      = $3 eq ']' ? 1 : 0;
        $slurp{chomp}       = 1 if $4;
    } 

    return %slurp;
}

sub find {
    return shift->split( @_ );
}

sub split {
    my $self = shift;
    my $matcher;
    $matcher = shift if @_ % 2; # Odd number of arguments
    my %given = @_;

    my $data = $self->data;
    my $from = $self->_parent ? $self->tail + 1 : 0;
    my $length = length $$data;

    return if $length <= $from; # Was already at end of data

    pos $data = $from;
    return unless $$data =~ m/\G[[:ascii:]]*?($matcher)/mgc;
    my @match = map { substr $$data, $-[$_], $+[$_] - $-[$_] } ( 0 .. -1 + scalar @- );
    shift @match;
    my $found = shift @match;
    my ( $mhead, $mtail ) = ( $-[1], $+[1] - 1 );

    my $head = _fhead $data, $mhead;
    my $tail = _ftail $data, $mtail;

    # TODO This is hacky
    my @matched = @match;

    my $content = substr $$data, $head, 1 + $tail - $head;

    my $split =  __PACKAGE__->new(
        data => $data, parent => $self,
        start => $from, mhead => $mhead, mtail => $mtail, head => $head, tail => $tail,
        matcher => $matcher, found => $found, matched => \@matched,
        content => $content,
        default => $self->default,
    );

    return $split unless wantarray && ( my $slurp = delete $given{slurp} );
    return ( $split, $split->slurp( $slurp, %given ) );
}

sub slurp {
    my $self = shift;
    my $slurp = 1;
    $slurp = shift if @_ % 2; # Odd number of arguments
    my %given = @_;

    my $split = $self;

    _chomped2chomp \%given;
    my %slurp = _parse_slurp $self->default->{slurp};
    $slurp{chomp} = $given{chomp} if exists $given{chomp};
    %slurp = _parse_slurp $slurp, %slurp unless $slurp eq 1;

    my @content;
    push @content, $self->parent->content if $slurp{slurpl};
    push @content, $split->preceding;
    push @content, $split->content if $slurp{slurpr};

    if ( wantarray && $slurp{wantlist} ) {
        @content = grep { $_ ne "\n" } split m/(\n)/, join '', @content;
        @content = map { "$_\n" } @content unless $slurp{chomp};
        return @content;
    }
    else {
        return join '', @content;
    }
}

sub preceding {
    my $self = shift;

    my $data = $self->data;
    my $length = $self->head - $self->start;
    return '' unless $length;
    return substr $$data, $self->start, $length;
}
sub pre { return shift->preceding( @_ ) }

sub remaining {
    my $self = shift;

    my $data = $self->data;
    return $$data if $self->is_root;

    my $from = $self->tail + 1;

    my $length = length( $$data ) - $from + 1;
    return '' unless $length;
    return substr $$data, $from, $length;
}
sub re { return shift->remaining( @_ ) }

sub match {
    my $self = shift;
    my $ii = shift;
    return $self->found if $ii == -1;
    return $self->_matched->[$ii];
}

sub is {
    my $self = shift;
    my $ii = shift;
    my $is = shift;

    return unless defined ( my $match = $self->match( $ii ) );
    if ( ref $is eq 'Regexp' )  { $match =~ $is }
    else                        { return $match eq $is }
}

1;
