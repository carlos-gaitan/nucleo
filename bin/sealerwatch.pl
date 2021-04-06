#!/usr/bin/perl -w

use     strict;
use     warnings;
use     Math::BigInt;
use     Carp;
$Carp::Verbose                  =   1;
BEGIN {
    die "\$BFAHOME not set. Did you source bfa/bin/env ?\n"
        unless exists $ENV{BFAHOME};
}
use     lib $ENV{'BFAHOME'}.'/bin';
use     libbfa;
my      $libbfa;

package ansi;

our     $CSI                    =   "\x1b[";
sub     CUP             { $CSI.(shift||1).';'.(shift||1).'H' }
sub     EL              { $CSI.(shift||0).'K'   }
sub     ED              { $CSI.(shift||0).'J'   }
sub     normal          { $CSI.'m'              } 
sub     black           { $CSI.'30m'            }
sub     red             { $CSI.'41m'            }
sub     green           { $CSI.'42m'            }
sub     brightwhite     { $CSI.'97m'            }
sub     bgyellow        { $CSI.'103m'           }

package alias;
use     IO::File;

our     $initialised            =   0;
our     %list;

sub     translate
{
    my      $victim             =   lc shift;
    if ( ! $initialised )
    {
        $initialised            =   1;
        local   $_              =   undef;
        my      $fh             =   IO::File->new($libbfa->{'networkdir'}.'/aliases');
        if ( defined $fh )
        {
            while ( $_ = $fh->getline )
            {
                s|^\s+||;
                s|\s+$||;
                my      @e      =   split /\s+/, $_, 2;
                if ( scalar @e == 2 )
                {
                    my  $addr   =   lc $e[0];
                    $list{$addr}=   $e[1];
                }
            }
            $fh->close;
        }
    }
    return $list{$victim} if exists $list{$victim};
    return;
}

package tools;
our     $CSI                    =   "\x1b[";
our     $clearEOS               =   "${CSI}J";
our     $up                     =   "${CSI}A";
our     $red                    =   "${CSI}41m";
our     $normal                 =   "${CSI}m";

sub     new
{
    my ($class, $libbfa)        =   @_;
    my $self                    =   bless {}, ref $class || $class;
    return $self;
}

sub     gmt
{
  my $ts                        =   shift;
  return unless defined $ts;
  my @t                         =   gmtime($ts);
  $t[5]                         +=  1900;
  $t[4]                         ++;
  return sprintf('%04d%02d%02d-%02d%02d%02d', (@t)[5,4,3,2,1,0]);
}

sub     hex2string($)
{
  my ($msg)                     =   @_;
  my $txt                       =   '';
  while ($msg ne '')
  {
    my $i                       =   hex( substr($msg,0,2) );
    $txt                        .=  ( $i >= 32 and $i <= 127 ) ? chr($i) : '.';
    $msg                        =   substr $msg, 2;
  }
  return $txt;
}

sub     max(@)
{
    my      $num                =   0;
    local   $_                  =   undef;
    foreach $_ (@_)
    {
        $num                    =   $_
            if $num < $_;
    }
    return $num;
}

package error;
use     JSON;

sub     new
{
    my      ($class, $json_in)  =   @_;
    my      $self               =   bless {
        '_code'                 =>  undef,
        '_message'              =>  undef,
    }, ref $class || $class;
    my      $json;
    eval {
        $json                   =   decode_json( $json_in )
    };
    return unless defined $json;
    return unless exists  $json->{'error'};
    $self->code(    $json->{'error'}->{'code'}    )    if exists $json->{'error'}->{'code'};
    $self->message( $json->{'error'}->{'message'} )    if exists $json->{'error'}->{'message'};
    return  $self;
}

sub     code
{
    my      ( $self, $val )     =   @_;
    $self->{'_code'}            =   $val if scalar @_ > 1;
    return $self->{'_code'};
}

sub     message
{
    my      ( $self, $val )     =   @_;
    $self->{'_message'}         =   $val if scalar @_ > 1;
    return $self->{'_message'};
}

package block;
#use     LWP;
use     JSON;

sub     new
{
    my  ( $class, $libbfa )     =   @_;
    my  $self                   =   bless {}, ref $class || $class;
    $self->{'libbfa'}           =   $libbfa if defined $libbfa;
    return $self;
}

sub     parse
{
    my  ( $self, $json_raw )    =   @_;
    return unless defined $json_raw;
    return if $json_raw eq '';
    $self->{'json_raw'}         =   $json_raw;
    eval { $self->{'json'}      =   decode_json( $json_raw ) };
    return if $@;
    $self->error( error->new($json_raw) );
    return $self;
}

sub     error
{
  return if not exists $_[0]->{'error'};
  return $_[0]->{'error'};
}


sub     json
{
    return unless exists $_[0]->{'json'};
    return $_[0]->{'json'};
}

sub     result
{
    return unless exists $_[0]->{'json'}->{'result'};
    return $_[0]->{'json'}->{'result'};
}

sub     number
{
    return if not exists $_[0]->result->{'number'};
    return hex( $_[0]->result->{'number'} );
}

sub     difficulty
{
    return if not exists $_[0]->result->{'difficulty'};
    return hex( $_[0]->result->{'difficulty'} );
}

sub     td
{
    return if not exists $_[0]->result->{'totalDifficulty'};
    return hex( $_[0]->result->{'totalDifficulty'} );
}

sub     timestamp
{
    return if not exists $_[0]->result->{'timestamp'};
    return hex( $_[0]->result->{'timestamp'} );
}

sub     gasLimit
{
  return if not exists $_[0]->result->{'gasLimit'};
  return hex( $_[0]->result->{'gasLimit'} );
}

sub     miner
{
  return if not exists $_[0]->result->{'miner'};
  return $_[0]->result->{'miner'};
}

sub     nonce
{
  return if not exists $_[0]->result->{'nonce'};
  return lc $_[0]->result->{'nonce'};
}

sub     hash
{
  return if not exists $_[0]->result->{'hash'};
  return lc $_[0]->result->{'hash'};
}

sub     parentHash
{
  return if not exists $_[0]->result->{'parentHash'};
  return lc $_[0]->result->{'parentHash'};
}

sub     extradata
{
  return if not exists $_[0]->result->{'extraData'};
  my $t                         =   $_[0]->result->{'extraData'};
  return substr($t,2) if substr($t,0,2) eq '0x';
  return lc $t;
}

sub     sealers
{
    my $t                       =   $_[0]->extradata;
    return unless defined $t;
    $t                          =   substr $t,64;
    $t                          =   substr $t,0,-130;
    my @a;
    while ( length $t >= 40 )
    {
        push @a, substr($t, 0, 40);
        $t                      =   substr $t, 40;
    }
    return @a;
}

sub     get
{
    my  ($self, $number)        =   @_;
    my  $libbfa                 =   $self->{'libbfa'};
    my  $hexed                  =   $number =~ /^\d+$/ ? sprintf("0x%x",$number) : $number;
    my  $content                =   $libbfa->rpcreq( 'eth_getBlockByNumber', qq("$hexed"), "false");
    my  $block                  =   block->new( $libbfa );
    $block->parse( $content );
    return if not exists $block->{'json'};
    die $block->error->message if $block->error;
    return if not $block->result;
    return $block;
}

sub     print
{
    print scalar($_[0]->sprint),"\n";
}

my $nonce_xlate = { 
    '0x0000000000000000'        =>  'SEALER_REM',
    '0xffffffffffffffff'        =>  'SEALER_ADD',
};

sub     sprint
{
    my ( $self )                =   @_;
    my $txt                     =   '';
    my $lines                   =   1;
    my @sealers                 =   $self->sealers;
    if ( @sealers )
    {
        $txt                    =   sprintf "\r${tools::clearEOS}";
        $txt                    =   '';
        for my $sealer ( @sealers )
        {
            $txt                .=  sprintf
                "Confirming signer at epoch: 0x%s\n",
                $sealer;
            $lines++;
        }
    }
    $txt                        .=  sprintf
        '%s block:%s %s',
        tools::gmt($self->timestamp),
        $self->number,
        $self->sealer;
    if ( $self->miner !~ /^0x0{40}$/o )
    {
        # we have auth or drop
        my $nonce               =   $self->nonce;
        $nonce                  =   $nonce_xlate->{$nonce} if exists $nonce_xlate->{$nonce};
        $txt                    .=  sprintf " %s %s", $nonce, $self->miner;
    }
    return wantarray ? ($txt, $lines) : $txt;
}

package main;
use     JSON;

$| = 1;
chdir "$ENV{BFAHOME}" or die $!;
my      $number                 =   shift || 'latest';
my      $tools                  =   tools->new;
my      %cache;
my      $latestvalidblock;
my      %signers;
# If we started with 'latest' then subtract 100,
# so we get an updated list of recent signers faster.
my      $subtract               =   $number eq 'latest' ? 100 : 0;

$libbfa                         =   libbfa->new();
my      $block                  =   block->new( $libbfa )->get( $number );
die if not defined $block;
$number                         =   $block->number;
my      $run_to                 =   $number;
$number                         -=  $subtract;
print ansi::CUP().ansi::ED();

sub     determine_colour
{
    my      $diff               =   shift;
    return ansi::green() . ansi::brightwhite()
        if $diff == 0;
    return ansi::green()
        if $diff < scalar ( keys %signers );
    return ansi::bgyellow() . ansi::black()
        if $diff < 720; # one hour
    return ansi::red();
}

sub colour_split
{
    my      ($name, $diff, $col, $difficulty)
                                =   @_;
    return $name
        if $diff == 0;
    my  $len                    =   length $name;
    if ( $diff <= $len )
    {
        my      $part1          =   substr $name, 0,$len-$diff;
        my      $part2          =   substr $name, $len-$diff,1;
        my      $part3          =   substr $name, $len-$diff+1;
        if ( $difficulty == 2 )
        {
            $part3              =   $part2 . $part3;
            $part2              =   '';
        }
        $part2                  =   ansi::bgyellow() . ansi::black() . $part2 . ansi::normal()
            if $part2 ne '';
        return
            $part1 .
            $part2 .
            (( $col eq '' ) ? ansi::green() : $col) .
            $part3 .
            ansi::normal();
    }
    # diff > len
    return
        ansi::red() . substr( $name, 0, 1 ) . ansi::normal() .
        $col . substr( $name, 1 ) . ansi::normal();
}

my      $maxy                   =   2;
sub     presentation_top
{
    my  $block                  =   shift;
    return if not defined $block;
    #
    my      $warning            =   '';
    if    ( $block->timestamp + 1800 < time() )
    {
        $warning                =   '  ' . ansi::red()      . " **NOT RECENT** " . ansi::normal()
    }
    elsif ( $block->timestamp +   30 < time() )
    {
        $warning                =   '  ' . ansi::bgyellow() . ansi::black() . " **NOT RECENT** " . ansi::normal()
    }
    print
        ansi::CUP(),
        ansi::normal(),
        tools::gmt($block->timestamp),
        $warning,
        ansi::EL(0),
        ansi::CUP($maxy, 1);
}

while ( defined $block || sleep 1 )
{
    my      $parent             =   undef;
    my      $prospect           =   block->new( $libbfa )->get( $number );
    $block                      =   $prospect
        if defined $prospect;
    presentation_top( $block );
    next
        if not defined $prospect;
    $cache{$number}{'block'}    =   $block;
    $number                     =   $block->number;
    if ( exists $cache{ $number - 1 }{'block'} )
    {
        $parent                 =   $cache{ $number - 1 }{'block'};
        # If we do have any information about previous blocks,
        # see if the hash matches. If we were in a side branch
        # we would eventually get wrong hashes, because we
        # ask for blocknumbers (block height).
        # This is a good way to determine if we're side tracked.
        if ( $parent->hash ne $block->parentHash )
        {
            # First delete the signer of the to-be-forgotten block
            # from the list of 'recent signs'. This will create a
            # red 'n/a' to appear in the list. This is more desirable
            # than finding the proper previous block of this signer,
            # as it makes it more visual that a fork had happened.
            my      $prevsigner =   $cache{ $number - 1 }{'signer'};
            delete $signers{$prevsigner};
            # If we are side tracked, we'll read backwards
            # until we find a match (or until we have nothing cached)
            delete $cache{$number};
            $number             --;
            next;
        }
    }
    my      $hexed              =   $number =~ /^\d+$/ ? sprintf("0x%x",$number) : $number;
    my      $snapjson           =   $libbfa->rpcreq( 'clique_getSnapshot', qq("$hexed") );
    die     unless defined $snapjson;
    die     if $snapjson eq '';
    my      $snapparsed;
    $snapparsed                 =   decode_json( $snapjson );
    my      $result             =   $snapparsed->{'result'};
    my      $thissigner         =   $result->{'recents'}{$number};
    #
    # Make sure we only have current signers listed
    my      %newsigners         =   ();
    for my $this (sort keys %{ $result->{'signers'} } )
    {
        $newsigners{$this}      =   $signers{$this}
            if exists $signers{$this};
    }
    %signers                    =   %newsigners;
    $signers{$thissigner}       =   $number;
    $cache{$number}{'signer'}   =   $thissigner;
    #
    # presentation
    my      $num_max_width      =   tools::max( length $number, 3 );

    print ansi::CUP(2,1);
    foreach my $this ( sort keys %{ $result->{'signers'}} )
    {
        my      $lastnum        =   exists $signers{$this} ? $signers{$this} : -12345;
        my      $diff           =   $number - $lastnum;
        my      $col            =   determine_colour( $diff );
        my      $difficulty     =   ( exists $signers{$this} and exists $cache{$signers{$this}}{'block'} )
            ?   $cache{$signers{$this}}{'block'}->difficulty
            :   0;
        my      $id             =   colour_split( $this, $diff, $col, $difficulty );
        my      $flags          =   $diff == 0 ? '*' : '';
        my      $alias          =   alias::translate( $this );
        my      $numtxt         =   (not defined $lastnum or $lastnum < 0) ? 'n/a' : $lastnum;
        printf "%s%-1s%s%-${num_max_width}s%s %s%s\n",
            $id, $flags, $col, $numtxt, ansi::normal(),
            defined $alias ? $alias : '',
            ansi::EL(0);
    }
    $maxy                       =   scalar( keys %{ $result->{'signers'} }) + 2;
    print ansi::ED(0), ansi::CUP($maxy, 1);
    #
    $number                     =   $block->number + 1;
    select( undef, undef,undef, 0.1 )
        if $number >= $run_to;
}
