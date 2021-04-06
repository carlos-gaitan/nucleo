# 20180927 Robert Martin-Legene <robert@nic.ar>

package libbfa;
use     Math::BigInt;
use     IO::File;
use     LWP;
use     JSON;
use     Carp;
$Carp::Verbose  =   1;

sub     _cat
{
    my      ( $self, $filename )    =   @_;
    my      $fh         =   IO::File->new($filename);
    return if not defined $fh;
    local   $_          =   join( '', $fh->getlines );
    $fh->close;
    return if not defined $_;
    s|^\s+||;
    s|\s+$||;
    return if $_ eq '';
    return $_;
}

sub     _filecontents_or_default
{
    my  ($self, $filename, $default)   =   @_;
    local   $_  =   $self->_cat( $filename );
    return  defined $_ ? $_ : $default;
}

sub     new
{
    my  ( $class )      =   @_;
    my $self = bless {}, ref $class || $class;
    # BFAHOME
    die '$BFAHOME not set. Did you source bfa/bin/env ?\n'
        if not exists $ENV{'BFAHOME'};
    $self->{'home'} = $ENV{'BFAHOME'};
    # BFANETWORKID
    $self->{'networkid'} = $ENV{'BFANETWORKID'} =
        exists $ENV{'BFANETWORKID'}
        ? $ENV{'BFANETWORKID'}
        : 47525974938;
    # BFANETWORKDIR
    $self->{'networkdir'} = $ENV{'BFANETWORKDIR'} =
        exists $ENV{'BFANETWORKDIR'}
        ? $ENV{'BFANETWORKDIR'}
        : $self->{'home'}.'/network';
    # BFANODEDIR
    $self->{'nodedir'} = $ENV{'BFANODEDIR'} =
        exists $ENV{'BFANODEDIR'}
        ? $ENV{'BFANODEDIR'}
        : $self->{'networkdir'}.'/node';
    # ACCOUNT
    if ( not exists $ENV{'BFAACCOUNT'} ) {
        my  $dir    =   $self->{'nodedir'};
        my  @files  =   sort <${dir}/*--*>;
        # found none?
        if (scalar(@files) > 0 )
        {
            my  $file   =   $files[0];
            $file       =~  s/^.*--//;
            $self->{'account'} = $ENV{'BFAACCOUNT'} =
                '0x' . $file;
        }
    }
    #
    $self->{'netport'}  =   $self->_filecontents_or_default( $self->{'nodedir'}.'/netport', 30303 );
    $self->{'rpcport'}  =   $self->_filecontents_or_default( $self->{'nodedir'}.'/rpcport',  8545 );
    $self->{'rpchost'}  =   $self->_filecontents_or_default( $self->{'nodedir'}.'/rpchost', 'http://localhost' );
    $self->{'ua'}       =   LWP::UserAgent->new;
    return $self;
}

sub     contract
{
    my  $self       =   shift;
    my  $contract   =   {};
    my  $contname   =   shift;
    my  $contdir    =   join('/', [ $self->{'networkdir'}, 'contracts', $contname ] );
    my  $contaddr   =   readlink $contdir;
    return if not defined $contaddr;
    $contaddr       =~  s|^.*/||;
    $contract->{'address'}  =   #contaddr;
    my  $abistr     =   $self->_cat( $contdir . '/abi' );
    die "Can not find abi file, stopped" if not defined $abistr;
    eval { my $contract->{'abi'} = decode_json( $abistr ) };
    die "Can not decode json, stopped" if not defined $contract->{'abi'};
    return $contract;
}

sub     rpcreq
{
    my  ( $self, $opname, @params )
                                =   @_;
    my      $ua                 =   $self->{'ua'}->clone;
    $ua->ssl_opts( 'verify_hostname' => 0 );
    my      $endpoint           =   sprintf '%s:%d', $self->{rpchost}, $self->{'rpcport'};
    my      $extra              =   scalar @params
        ? sprintf(qq(,\"params\":[%s]), join(',', @params))
        : '';
    #
    my      $res                =   $ua->post(
        $endpoint,
        'Content-Type'          =>  'application/json',
        'Content'               =>  qq({"jsonrpc":"2.0","method":"${opname}"${extra},"id":1}),
    );
    die $res->status_line
        unless $res->is_success;
    return $res->content;
}

1;
