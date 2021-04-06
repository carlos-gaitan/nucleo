#!/usr/bin/perl -w

use strict;
use warnings;
use IO::File;
use Math::BigInt;
use Carp;
$Carp::Verbose  =   1;
BEGIN {
    die "\$BFAHOME not set. Did you source bfa/bin/env ?\n"
        unless exists $ENV{BFAHOME};
}
use lib $ENV{'BFAHOME'}.'/bin';
use libbfa;
use Data::Dumper;
my  $libbfa;

package tools;
use Data::Dumper;
my  $ua		=   LWP::UserAgent->new;
our $CSI        =   "\x1b[";
our $clearEOS   =   "${CSI}J";
our $up         =   "${CSI}A";
our $red        =   "${CSI}41m";
our $normal     =   "${CSI}m";

sub new
{
    my ($class, $libbfa)    =   @_;
    my $self    =   bless {}, ref $class || $class;
    $self->{'libbfa'}       =   $libbfa;
    return $self;
}

sub wait
{
    my $i = ++$_[0]->{'wait'};
    printf "%s%c[D", substr('|/-\\', $i%4, 1), 27;
    sleep 1;
}

sub cat($)
{
  my ($filename) = @_;
  my $fh = IO::File->new($filename) or return;
  return join('', $fh->getlines);
}

sub gmt
{
  my $ts = shift;
  return unless defined $ts;
  my @t  = gmtime($ts);
  $t[5]+=1900;
  $t[4]++;
  return sprintf('%04d%02d%02d-%02d%02d%02d', (@t)[5,4,3,2,1,0]);
}

sub hex2string($)
{
  my ($msg)=@_;
  my $txt = '';
  while ($msg ne '')
  {
    my $i=hex( substr($msg,0,2) );
    my $c='.';
    $c=chr($i) if $i >= 32 and $i <= 127;
    $txt .= $c;
    $msg=substr $msg, 2;
  }
  return $txt;
}

sub rpcreq
{
    my  ( $opname, @params ) = @_;
    my  $req        =   HTTP::Request->new( POST => 'http://127.0.0.1:8545' );
    $req->content_type('application/json');
    my $extra      =   scalar @params
        ? sprintf(qq(,\"params\":[%s]), join(',', @params))
        : '';
    $req->content( qq({"jsonrpc":"2.0","method":"${opname}"${extra},"id":1}));
    my  $res        =   $ua->request($req);
    die $res->status_line
        unless $res->is_success;
    return $res->content;
}

package balance;
use JSON;
use Data::Dumper;

sub new
{
    my  ($class, $libbfa, $acct, $at) = @_;
    my  $self = bless {}, ref $class || $class;
    $self->{'libbfa'}   =   $libbfa;
    $self->get( $acct, $at ) if defined $acct;
    return $self;
}

sub acct
{
    my  ($self, $acct) = @_;
    if ( defined $acct )
    {
        $acct   =   '0x'.$acct if $acct !~ /^0x/;
        $self->{'_acct'} = $acct;
    }
    return unless exists $self->{'_acct'};
    return $self->{'_acct'};
}

sub at
{
    my  ($self, $at) = @_;
    $self->{'_at'} = $at if defined $at;
    return sprintf('0x%x', $self->{'_at'}) if exists $self->{'_at'};
    return 'latest';
}

sub get
{
    my      ($self, $acct, $at) = @_;
    my      $libbfa         =   $self->{'libbfa'};
    $self->acct($acct)  if defined $acct;
    $self->at($at)      if defined $at;
    my      @params         =   ( sprintf(qq("%s","%s"),$self->acct,$self->at) );
    my      $content        =   $libbfa->rpcreq( 'eth_getBalance', @params );
    my      $json;
    eval { $json = decode_json( $content ) };
    my      $error          =   error->new( $content );
    if ( $error )
    {
        my $msg = '';
        return 'NOTFOUND' if $error->message =~ /^missing trie node /;
        die join(' * ', @params, $content);
        return;
    }
    die if not exists  $json->{'result'};
    die if not defined $json->{'result'};
    return Math::BigInt->from_hex( $json->{'result'} );
}

package error;
use JSON;
use Data::Dumper;

sub new
{
    my      ($class, $json_in)  =   @_;
    my      $json;
    eval { $json = decode_json( $json_in ) };
    return unless defined $json;
    return unless exists $json->{'error'};
    my      $self = bless {
        '_code'     =>  undef,
        '_message'  =>  undef,
    }, ref $class || $class;
    $self->code(    $json->{'error'}->{'code'}    )    if exists $json->{'error'}->{'code'};
    $self->message( $json->{'error'}->{'message'} )    if exists $json->{'error'}->{'message'};
    return  $self;
}

sub code
{
    my      ( $self, $val ) = @_;
    $self->{'_code'} = $val if scalar @_ > 1;
    return $self->{'_code'};
}

sub message
{
    my      ( $self, $val ) = @_;
    $self->{'_message'} = $val if scalar @_ > 1;
    return $self->{'_message'};
}

package block;
use LWP;
use JSON;
use Data::Dumper;

sub new
{
    my  ( $class, $libbfa )     =   @_;
    my  $self                   =   bless {}, ref $class || $class;
    $self->{'libbfa'}           =   $libbfa;
    return $self;
}

sub parse
{
    my  ( $self, $json_raw )     =   @_;
    $self->{'libbfa'}           =   $libbfa;
    return unless defined $json_raw;
    return if $json_raw eq '';
    $self->{'json_raw'}         =   $json_raw;
    eval { $self->{'json'}      =   decode_json( $json_raw ) };
    return if $@;
    $self->error( error->new($json_raw) );
    return $self;
}

sub error
{
  return if not exists $_[0]->{'error'};
  return $_[0]->{'error'};
}


sub json
{
    return unless exists $_[0]->{'json'};
    return $_[0]->{'json'};
}

sub result
{
    return unless exists $_[0]->{'json'}->{'result'};
    return $_[0]->{'json'}->{'result'};
}

sub number
{
    return if not exists $_[0]->result->{'number'};
    return hex( $_[0]->result->{'number'} );
}

sub td
{
    return if not exists $_[0]->result->{'totalDifficulty'};
    return hex( $_[0]->result->{'totalDifficulty'} );
}

sub timestamp
{
    return if not exists $_[0]->result->{'timestamp'};
    return hex( $_[0]->result->{'timestamp'} );
}

sub gasLimit
{
  return if not exists $_[0]->result->{'gasLimit'};
  return hex( $_[0]->result->{'gasLimit'} );
}

sub miner
{
  return if not exists $_[0]->result->{'miner'};
  return $_[0]->result->{'miner'};
}

sub nonce
{
  return if not exists $_[0]->result->{'nonce'};
  return lc $_[0]->result->{'nonce'};
}

sub hash
{
  return if not exists $_[0]->result->{'hash'};
  return lc $_[0]->result->{'hash'};
}

sub parentHash
{
  return if not exists $_[0]->result->{'parentHash'};
  return lc $_[0]->result->{'parentHash'};
}

sub extradata
{
  return if not exists $_[0]->result->{'extraData'};
  my $t = $_[0]->result->{'extraData'};
  return substr($t,2) if substr($t,0,2) eq '0x';
  return lc $t;
}

sub sealers
{
    my $t = $_[0]->extradata;
    return unless defined $t;
    $t = substr $t,64;
    $t = substr $t,0,-130;
    my @a;
    while ( length $t >= 40 )
    {
        push @a, substr($t, 0, 40);
        $t = substr $t, 40;
    }
    return @a;
}

sub vanity
{
  my $t = $_[0]->extradata;
  return unless defined $t;
  return substr($t,0,64);
}

sub clear
{
    my  $t  =   shift;
    return unless defined $t;
    return substr($t,2) if substr($t,0,2) eq '0x';
    return $t;
}

sub get
{
    my  ($self, $number)    =   @_;
    my  $cachefile;
    if ( $number =~ /^[0-9]+$/ )
    {
        $number             =   sprintf('0x%x', $number);
        $cachefile          =   "cache/block.$number";
    }
    my  $libbfa             =   $self->{'libbfa'};
    my  $block              =   block->new( $libbfa );
    if ( defined $cachefile and -r $cachefile )
    {
        $block              =   $block->parse( tools::cat $cachefile );
        return $block
            if defined $block and not $block->error;
        # We delete the cache file if we couldn't use the data in it.
        unlink $cachefile;
        # and then we continue to fetch it
    }
    my $content             =   tools::rpcreq( 'eth_getBlockByNumber', qq("$number"), "false");
    $block                  =   $block->parse( $content );
    return if not defined $block;
    return if not exists $block->{'json'};
    die $block->error->message if $block->error;
    return if not $block->result;
    if ( defined $cachefile )
    {
        my  $fh                 =   IO::File->new( $cachefile, 'w' ) or die $!;
        $fh->print( $block->{'json_raw'} );
        $fh->close;
    }
    return $block;
}

sub delete_cache
{
    my  ($self)     =   @_;
    unlink sprintf('cache/block.0x%x', $self->number);
}

sub print
{
    print scalar($_[0]->sprint),"\n";
}

my $nonce_xlate = { 
    '0x0000000000000000' => 'SEALER_REM',
    '0xffffffffffffffff' => 'SEALER_ADD',
};

sub sprint
{
    my ( $self )    =   @_;
    my $txt         =   '';
    my $lines       =   1;
    my @sealers     =   $self->sealers;
    if ( @sealers )
    {
        $txt    =   sprintf "\r${tools::clearEOS}";
        $txt    =   '';
        for my $sealer ( @sealers )
        {
            $txt.=  sprintf
                "Confirming signer at epoch: 0x%s with an ETH balance of %s\n",
                $sealer,
                balance->new($libbfa, $sealer, $self->number);
            $lines++;
        }
    }
    $txt        .=  sprintf
        '%s block:%s gaslimit:%s td:%d Vanity:%s',
        tools::gmt($self->timestamp),
        $self->number,
        $self->gasLimit,
        $self->td,
        tools::hex2string($self->vanity);
    if ( $self->miner !~ /^0x0{40}$/o )
    {
        # we have auth or drop
        my $nonce   =   $self->nonce;
        $nonce      =   $nonce_xlate->{$nonce} if exists $nonce_xlate->{$nonce};
        $txt        .=  sprintf " %s %s", $nonce, $self->miner;
    }
    return wantarray ? ($txt, $lines) : $txt;
}

package main;
use Data::Dumper;

$| = 1;
chdir "$ENV{BFAHOME}" or die $!;
mkdir 'cache';
my      $number     =   shift || 'latest';
my      $tools      =   tools->new;
my      $parent;

$libbfa             =   libbfa->new();
while ( 1 )
{
    my  $block      =   block->new->get( $number );
    if ( not defined $block )
    {
        $tools->wait();
        next;
    }
#print Dumper(['block'=>$block]);
    $number         =   $block->number;
    if (not defined $parent and
        $block->number > 1)
    {
        $parent     =   $block->get( $block->number-1 );
    }
    if ( defined $parent and
        $parent->hash ne $block->parentHash )
    {
        printf "\r${tools::red}%s${tools::normal}\n", scalar($parent->sprint);
        ($parent, $block, $number) = (undef, $parent, $number-1);
        $block->delete_cache;
        next;
    }
    $block->print;
    $number         =   $block->number + 1;
    $parent         =   $block;
}
