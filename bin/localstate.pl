#!/usr/bin/perl -w
# Robert Martin-Legene <robert@nic.ar>
# 20190423(c) NIC Argentina, GPLv2.

# apt install libclass-accessor-perl libmath-bigint-perl

use     strict;
use     warnings;
use     Carp;
use     Math::BigInt;
use     JSON;
use     IO::Socket::INET;
BEGIN {
    die "\$BFAHOME not set. Did you source bfa/bin/env ?\n"
        unless exists $ENV{BFAHOME};
}
my      %network                =   (
    47525974938     =>  'BFA red principal [est. 2018]',
    55555000000     =>  'BFA red de pruebas numero 2 [est. 2019]',
);
chdir   $ENV{BFAHOME} or die $!;
use     lib $ENV{'BFAHOME'}.'/bin';
use     libbfa;

package error;
use     JSON;
use     Carp;

sub     new
{
    my      ($class, $json_in)  =   splice(@_,0,2);
    my      $opt                =   pop @_ || {};
    my      $self               =   bless {
        '_code'                 =>  undef,
        '_message'              =>  undef,
    }, ref $class || $class;
    confess "No input JSON received, stopped" unless defined $json_in;
    my      $json;
    if ( ref $json_in eq '' ) 
    {
        eval {
            $json                   =   decode_json( $json_in );
        };
        confess $@ if $@;
    }
    if ( exists $json->{'error'} )
    {
        $self->code(    $json->{'error'}->{'code'}    )    if exists $json->{'error'}->{'code'};
        $self->message( $json->{'error'}->{'message'} )    if exists $json->{'error'}->{'message'};
        confess sprintf( "%s: %s, stopped", $self->code || 'undef', $self->message || 'undef' )
            if $opt->{fatal};
    }
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
use     Math::BigInt;
use     base qw( Class::Accessor );

__PACKAGE__->mk_accessors(qw(
  difficulty extraData gasLimit gasUsed hash logsBloom miner mixHash nonce
  number parentHash receiptsRoot sha3Uncles size stateRoot timestamp
  totalDifficulty transactions transactionsRoot uncles
));

sub new {
    my      ($class, $fields)   =   @_;
    my      $self               =   bless {}, ref $class || $class;
    foreach my $k ( keys %$fields )
    {
        $self->$k( ${$fields}{$k} );
    }
    return  $self;
}

sub set
{
    my      ($self, $key)       =   splice(@_, 0, 2);

    if (@_ == 1)
    {
        $_[0]                   =   Math::BigInt->new( $_[0] )
            if $_[0] =~ /^(?:0x[\da-fA-F]+|\d+)$/;
        $self->{$key}           =   $_[0];
    }
    elsif (@_ > 1)
    {
        $self->{$key}           =   [@_];
    }
    else
    {
        $self->_croak("Wrong number of arguments received");
    }
}

package main;

my      $libbfa                 =   libbfa->new();
my      $result;

sub     gmt
{
    my $ts                      =   shift;
    return unless defined $ts;
    my @t                       =   gmtime($ts);
    $t[5]                       +=  1900;
    $t[4]                       ++;
    return sprintf(
        '%04d-%02d-%02dT%02d:%02d:%02dZ',
        (@t)[5,4,3,2,1,0]
    );
}

sub     nicetimedelta
{
    my      $s                  =   shift;
    my      $t                  =   '';
    my      %intervals          =   ( w => 604800, d => 86400, h => 3600, m => 60, s => 1 );
    foreach my $letter (qw/ w d h m s /)
    {
        my  $n                  =   $intervals{$letter};
        if ( $s >= $n or $t ne '')
        {
            $t                  .=  sprintf '%02d%s', $s / $n, $letter;
            $s                  %=  $n;
        }
    }
    return $t eq '' ? '0s' : $t;
}

sub     rpc
{
    my      ($libbfa, $procedure, @args)    =   @_;
    my      $content            =   $libbfa->rpcreq( $procedure, @args );
    confess unless $content;
    my      $json               =   decode_json( $content );
    confess "$content, stopped" unless defined $json;
    error->new( $json, {fatal=>1} );
    return  $json->{'result'};
}

my	$netversion		=   rpc( $libbfa, 'net_version' );
if ( $netversion )
{
        if ( exists $network{$netversion} )
        {
	    printf "Running on network %s (#%s)\n", $network{$netversion}, $netversion;
        } else {
	    printf "Running on network %s\n", $netversion;
        }
}

### compare time
use     constant    days70y    =>   25567;

my  $s      =   IO::Socket::INET->new(
        PeerAddr    => "time.nist.gov:37",
        Timeout     => 3,
    );
if ( defined $s )
{
    $s->recv(my $data, 8);
    my  $i      =   unpack('N', $data) || 0;
    if ( $i > 0 )
    {
        # rfc868 offset (seconds from 1900-01-01 to 1970-01-01)
        $i -= 2208988800;
        printf "NIST time: %s\n", scalar(localtime($i));
        my  $heretime       =   time();
        printf "Here time: %s\n", scalar(localtime($i));
        if ( abs($i - $heretime) > 5 )
        {
            print "WHY IS YOUR CLOCK OFF?";
        }
    }
}

### latest block
$result                         =   rpc( $libbfa, 'eth_getBlockByNumber', '"latest"', "true" );
my      $block                  =   block->new( $result );
my      $timediff               =   time()-$block->timestamp;
printf
    "Our latest block number is %d. It's timestamp says %s (%s old).\n",
    $block->number,
    gmt($block->timestamp),
    nicetimedelta( $timediff );

### syncing ?
my      $syncing                =   rpc( $libbfa, 'eth_syncing' );
if ( $syncing )
{
        my      $current        =   Math::BigInt->new( $syncing->{'currentBlock'} );
        my      $highest        =   Math::BigInt->new( $syncing->{'highestBlock'} );
        my      $starting       =   Math::BigInt->new( $syncing->{'startingBlock'} );
        my      $startgap       =   $highest->copy->bsub( $starting );
        my      $synced         =   $current->copy->bsub( $starting );
        my      $pct            =   100.0 * $synced / $startgap;
        printf  "%d%% done syncing %d blocks.\n", int($pct), $startgap;
}
else
{
    if ( $timediff > 90 )
    {
        print "We are currently not syncing. WHY ARE OUR BLOCKS SO OLD?\n";
    } else {
        print "We have all the blocks and are not syncing.\n";
    }
}

### mining ?
$result                         =   rpc( $libbfa, 'eth_mining' );
if ( $result )
{
    printf  "We are a sealer and are configured seal.\n";
} else {
    print "We do not seal.\n";
}

# List peers
$result                         =   rpc( $libbfa, 'admin_peers' );
# Can be undef if the admin module is not enabled in geth (opentx).
if ( defined $result )
{
    my      $i                  =   0;
    foreach my $peer ( sort { $a->{'network'}{'remoteAddress'} cmp $b->{'network'}{'remoteAddress'} } @$result )
    {
        if ( ref $peer->{'protocols'}->{'eth'} eq 'HASH' )
        {
            print "[I]n/[O]ut [S]tatic [T]rusted\n" if $i == 0;
            $i++;
            my  $ip             =   $peer->{'network'}->{'remoteAddress'};
            $ip                 =~  s/:\d+$//; #port
            $ip                 =~  s/^\[(.*)\]$/$1/; #ipv6
            printf "[%s%s%s] %s\n",
                $peer->{'network'}->{'inbound'} ? 'I' : 'O',
                $peer->{'network'}->{'static'}  ? 'S' : ' ',
                $peer->{'network'}->{'trusted'} ? 'T' : ' ',
                $ip;
        }
    }
    printf "We are connected to %d peer%s.\n", $i, $i==1?'':'s';
}

# See recent signers - but skip if we are syncing, since that makes little sense.
my      %signers;
    $result                     =   rpc( $libbfa, 'clique_getSnapshot', '"latest"' );
    # Can be undef if the clique module is not enabled in geth (opentx).
    if ( defined $result )
    {
        %signers                =   %{$result->{'signers'}};
    }
    if ( defined $result and not defined $syncing )
    {
        my      %recents        =   %{$result->{'recents'}};
        my      $i              =   -98765;
        foreach my $s ( sort keys %signers )
        {
            $signers{$s}        =   $i--;
        }
        foreach my $n ( keys %recents )
        {
            my  $actor          =   $recents{$n};
            $signers{$actor}    =   $n;
        }
        my      $nplusone       =   int(scalar(keys %signers)/2)+1;
        my      $threshold      =   $block->number->copy->binc->bsub($nplusone);
        foreach my $s ( sort { $signers{$a} <=> $signers{$b} } keys %signers )
        {
            my      $this       =   Math::BigInt->new( $signers{$s} );
            my      $cmp        =   $threshold->bcmp( $this );
            next    unless defined $cmp;
            if ( $cmp < 0 )
            {
                printf "Signer %s signed block %d recently.\n", $s, $this;
            }
            else
            {
                printf "Signer %s is allowed to sign next block.\n", $s;
            }
        }
    }

## List accounts
$result                         =   rpc( $libbfa, 'eth_accounts' );
if ( $result )
{
    my      $i                  =   0;
    if ( scalar @$result )
    {
        foreach my $account ( @$result )
        {
            my      $maymine    =   '';
            $maymine            =   'sealer'
                if exists $signers{$account};
            printf "Locally available account%s:\n", scalar @$result == 1 ? '' : 's'
                if $i++ == 0;
            my      $txn        =   rpc( $libbfa, 'eth_getTransactionCount', qq("$account"), '"latest"' );
            $txn                =~  s/^0x([a-fA-F\d]+)$/hex($1)/e;
            my      $gold       =   rpc( $libbfa, 'eth_getBalance', qq("$account"), '"latest"' );
            $gold               =   Math::BigInt->new( $gold ) if $gold =~ /^0x/;
            printf "Account %d: %s %-6s %3d transaction%s, %s wei.\n", $i, $account, $maymine, $txn, ($txn==1?' ':'s'), $gold;
        }
    }
    else
    {
        print   "No accounts are locally available.\n";
    }
}
