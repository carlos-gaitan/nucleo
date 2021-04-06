#!/usr/bin/node
// 20201019 Robert Martin-Legene

/*
Copyright 2020 de la Dirección General de Sistemas Informáticos – Secretaría Legal y Técnica - Nación - Argentina.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/
*/


const   Web3                =   require( 'web3' );
const   fs                  =   require( 'fs' );
var     web3                =   new Web3();

function usage(exitvalue)
{
    console.log("Usage: "+process.argv[1]+" sign <keyfilename> [<password>]");
    console.log("   or: "+process.argv[1]+" recover <signature>");
    console.log("   or: "+process.argv[1]+" --help");
    process.exit(exitvalue);
}

if ( process.argv.length < 3 )
    usage( 1 );
if ( process.argv[2] == '--help' )
    usage( 0 );

if ( process.argv[2] == 'recover' )
{
    if ( process.argv.length != 4 )
        usage( 1 );
    recover( process.argv[3] );
}
else
if ( process.argv[2] == 'sign' )
{
    if ( process.argv.length < 4 || process.argv.length > 5 )
        usage( 1 );
    sign( process.argv[3], process.argv[4] || '');
}
else
    usage( 1 );

function sign( filename, password )
{
    var     filecontents;
    try {
        filecontents        =   fs.readFileSync( filename, 'utf8' );
    } catch {
        console.error( "Unable to read the file containing the key." );
        usage(1);
    }
    var     jsonacct;
    try {
        jsonacct            =   JSON.parse( filecontents );
    } catch {
        console.error( "Unable to parse the contents of the key file." );
        usage(1);
    }
    var     account;
    try {
        account             =   web3.eth.accounts.decrypt( jsonacct, password );
    } catch {
        console.error( "Unable to unlock the account with the password specified." );
        usage(1);
    }
    var signed              =   web3.eth.accounts.sign( "", account.privateKey );
    var signature           =   signed.signature;
    console.log( "The signature of the message is\n" + signature );
}

function recover( signature )
{
    var acctsigner          =   web3.eth.accounts.recover( "", signature );
    console.log( "The message was signed by\n" + acctsigner );
}
