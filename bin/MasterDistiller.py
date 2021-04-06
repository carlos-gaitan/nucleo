#!/usr/bin/python3

import sys
import os
if not os.environ.get('BFAHOME'):
    print("$BFAHOME not set. Did you source bfa/bin/env ?", file=sys.stderr)
    exit(1)
import json
import re
import decimal
import argparse
sys.path.append( os.path.join(os.environ['BFAHOME'],'bin' ))
import libbfa
bfa                 =   None
notation            =   dict()
janitor             =   None
distillery          =   None

def distbalance() -> int:
    return bfa.w3.eth.getBalance(distillery.address)

def distribute():
    # trigger distribution
    beforeBal = distbalance()
    rcpt = janitor.transact( web3=bfa.w3, function=distillery.functions.distribute, extragas=4000000)
    print('Distribute returned succesfully in block# {} using {} gas.'.format(rcpt.blockNumber, rcpt.gasUsed))
    afterBal = distbalance()
    print('Distributed {} {}.'.format( int(decimal.Decimal(beforeBal - afterBal) / notation['num']), notation['name']))

def editAccount(entry:str, beneflist:list):
    acct                =   None
    # is it an account address?
    if entry == '':
        # Do nothing, basically just update the display
        pass
    elif re.search('^0x[0-9a-fA-F]{40}$', entry):
        acct            =   entry.lower()
    # is it a known account address?
    elif re.search('^[0-9]+$', entry) and int(entry) < len(beneflist):
        acct            =   beneflist[int(entry)].addr
    elif entry == 'x':
        distribute()
    else:
        print('I do not know what to do with "{}".'.format(entry), file=sys.stderr)
        exit(1)
    if acct is None:
        return
    answer = input('Adjust the {} fill value of {} (setting to 0 is the same as deleting)\nAmount?: '.format(notation['name'], acct))
    if re.search('^[0-9\.]+$', answer) is None:
        print('I have no idea what to do with "{}".'.format(answer), file=sys.stderr)
        exit(1)
    print('Sending update to the SC...')
    weilimit = float(answer) * int(notation['num'])
    rcpt = janitor.transact( bfa.w3.toChecksumAddress(acct), int(weilimit), web3=bfa.w3, function=distillery.functions.setEtherAllowance)
    if rcpt.status:
        print('Update accepted.')
    else:
        print('Update failed.')

def getBeneficiaries() -> list:
    count                   =   distillery.functions.numberOfBeneficiaries().call()
    beneflist               =   list()
    # Fetch addresses from the list in the contract.
    for i in range(count):
        print("Indexing accounts ({}/{})...\x1B[J\r".format(i,count), end='')
        (addr,topuplimit)   =   distillery.functions.atPosition(i).call()
        bal                 =   bfa.w3.eth.getBalance( addr )
        beneflist.append( { "addr": addr, "topuplimit": topuplimit, "balance": bal } )
    print("\r\x1B[J".format(i,count), end='')
    s                       =   lambda x:x['addr'].lower()
    beneflist.sort(key=s)
    return beneflist

def print_beneficiary_list(beneflist:list):
    # find the length of the longest number-string
    longestlimit            =   1
    longestbalance          =   1
    numformat               =   notation['strformat'].format
    for i in range(len(beneflist)):
        entry               =   beneflist[i]
        numstr              =   numformat(decimal.Decimal(entry['topuplimit']) / notation['num'])
        thislen             =   len(numstr)
        if thislen > longestlimit:
            longestlimit = thislen
        numstr              =   numformat(decimal.Decimal(entry['balance']) / notation['num'])
        thislen             =   len(numstr)
        if thislen > longestbalance:
            longestbalance = thislen
    # print them all
    theformat               =   '{:' + str(len(str(len(beneflist)-1))) + \
                                '}: {} fills to {:' + \
                                str(longestlimit) + \
                                '.' + \
                                str(notation['potency']) + \
                                'f} {} (has {:' + \
                                str(longestbalance) + \
                                '.' + \
                                str(notation['potency']) + \
                                'f}).'
    for i in range(len(beneflist)):
        entry               =   beneflist[i]
        numstr              =   numformat(decimal.Decimal(entry['topuplimit']) / notation['num'])
        while len(numstr) < longestlimit:
            numstr          =   ' ' + numstr
        print(theformat.format(
            i,
            bfa.w3.toChecksumAddress(entry['addr']),
            decimal.Decimal(entry['topuplimit'])/notation['num'],
            notation['name'],
            decimal.Decimal(entry['balance']) / notation['num']
        ))

def overview():
    while True:
        print( "The contract's account ({}) has {} {}.".format(
            distillery.address,
            int(decimal.Decimal(distbalance()) / notation['num']),
            notation['name']
        ))
        beneflist           =   getBeneficiaries()
        print_beneficiary_list(beneflist)
        answer = input("\n[ Q=quit x=distribute ]\n" +
                       "Which account to edit (enter index number or full account number)?: ")
        if answer is None or answer.upper() == 'Q':
            exit( 0 )
        editAccount(answer, beneflist)

def init(**kwargs):
    global janitor, notation, distillery, bfa;
    bfa                     =   libbfa.Bfa(kwargs.get('uri'))
    janitor                 =   libbfa.Account(kwargs.get('sender_addr'))
    table                   =   ('Kwei', 'Mwei', 'Gwei', 'micro', 'finney', 'ether',
                                 'kether', 'grand', 'mether', 'gether', 'tether')
    potency                 =   18
    notation['potency']     =   potency
    notation['name']        =   table[int(potency/3-1)]
    notation['num']         =   pow(10, potency)
    notation['strformat']   =   '{' + ':.{}f'.format(potency) + '}'
    abifile = ''
    if os.getenv('BFAHOME'):
        abifile = os.path.join(os.path.join(os.environ['BFAHOME'], 'network'))
    if os.getenv('BFANETWORKDIR'):
        abifile = os.path.join(os.environ['BFANETWORKDIR'])
    abifile = os.path.join(abifile, 'contracts', 'Distillery', 'abi')
    with open(abifile, 'rt', encoding='utf-8') as infile:
        abitxt = infile.read()
        abi = json.loads(abitxt)
    distillery              =   bfa.w3.eth.contract(address=kwargs.get('sc_addr'), abi=abi)

parser = argparse.ArgumentParser(description="Command interface for BFA2018 distillery1.")
parser.add_argument(
    '--uri',
    metavar='URI',
    nargs=1,
    default='prod',
    help='URI of node to connect to.')
parser.add_argument(
    '--sender-addr',
    metavar='ADDR',
    nargs=1,
    default='0xd15dd6dbbe722b451156a013c01b29d91e23c3d6',
    help='Address of controller of the smart contract.')
parser.add_argument(
    '--sc-addr',
    metavar='ADDR',
    nargs=1,
    default='0xECB6aFF6e38dC58C4d9AaE2F7927A282bcB77AC2',
    help='Address of smart contract.')
parser.add_argument(
    '--distribute',
    action='store_true',
    help='Run distribute once and then exit.')
parsed = parser.parse_args()
init(uri=parsed.uri, sc_addr=parsed.sc_addr, sender_addr=parsed.sender_addr)
if parsed.distribute:
    distribute()
else:
    overview()
