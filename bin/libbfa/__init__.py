import os
import sys
import subprocess
import json
import re
import web3
import web3.exceptions
import web3.middleware
import ecdsa
from Crypto.Hash import keccak
import eth_account;


class Bfa:

    def __init__(self, provider=''):
        if 'BFAHOME' not in os.environ:
            if os.path.isdir('/home/bfa/bfa'):
                os.putenv('BFAHOME', '/home/bfa/bfa')
            elif 'HOME' in os.environ and os.path.isdir(os.path.join(os.environ['HOME'], 'bfa')):
                os.putenv('BFAHOME', os.path.join(os.environ['HOME'], 'bfa'))
        if isinstance(provider, str):
            if provider in ['prod', 'bfa2018', 'network', '']:
                provider = web3.HTTPProvider("http://public.bfa.ar:8545/")
            elif provider in ['test2network', 'test2', 'test']:
                provider = web3.HTTPProvider("http://public.test2.bfa.ar:8545/")
            elif provider.startswith('http://') or provider.startswith('https://'):
                provider = web3.HTTPProvider(provider)
            else:
                raise ValueError('I do not know how to handle that provider.')
        w3 = web3.Web3(provider)
        # inject POA compatibility middleware
        w3.middleware_onion.inject(web3.middleware.geth_poa_middleware, layer=0)
        self.w3 = w3


class Account:

    def __init__(self, *args):
        if len(args) == 0:
            self.new()
            return
        accountname = None
        passphrase = ''
        if len(args) >= 1:
            accountname = args[0]
        if len(args) >= 2:
            passphrase = args[1]
        self.keyfile = None
        self.key = None
        self.unlock(accountname, passphrase)
        self.nonce = 0

    def __repr__(self) -> str:
        return str(dict(keyfile=self.keyfile, key=str(self.key)))

    def __str__(self) -> str:
        return self.address

    def new(self):
        acct = eth_account.Account.create()
        self.address = acct.address
        self.key = acct.key
        self.save()
        # print(acct.address)
        # print(acct.key.hex())
        return acct

    def save(self):
        dir = None
        if os.getenv('BFANODEDIR') and os.path.exists(os.path.join(os.environ['BFANODEDIR'], 'keystore')):
            dir = os.path.join(os.environ['BFANODEDIR'], 'keystore')
        elif os.getenv('BFANETWORKDIR') and os.path.exists(os.path.join(os.environ['BFANETWORKDIR'], 'node', 'keystore')):
            dir = os.path.join(os.environ['BFANETWORKDIR'], 'node', 'keystore')
        elif os.getenv('BFAHOME') and os.path.exists(os.path.join(os.environ['BFAHOME'], 'network', 'node', 'keystore')):
            dir = os.path.join(os.environ['BFAHOME'], 'network', 'node', 'keystore')
        elif os.getenv('HOME'):
            dir = os.path.join(os.environ['HOME'], '.ethereum', 'keystore')
            os.makedirs(dir, mode=0o700, exist_ok=True)
        else:
            raise OSError('I have no idea where to save the file.')
        self.keyfile = os.path.join(dir, self.address)
        encrypted = eth_account.Account.encrypt(self.key.hex(), '')
        try:
            with open(self.keyfile, 'w', encoding='utf=8') as outfile:
                outfile.write(str(encrypted).replace("'", '"'))
        except:
            # os.remove(filename)
            raise
        pass

    @staticmethod
    def findkeyfilesindirectories(**kwargs):
        pattern = ''
        if 'pattern' in kwargs:
            pattern = kwargs['pattern']
        # Remove leading 0x if present
        if pattern.startswith('0x'):
            pattern = pattern[2:]
        # Lower case the pattern (account name)
        pattern = pattern.lower()
        # Find candidate directories of where to look for accounts
        wheretolook = []
        if os.getenv('BFANODEDIR'):
            wheretolook += [os.path.join(os.environ['BFANODEDIR'], 'keystore')]
        elif os.getenv('BFANETWORKDIR'):
            wheretolook += [os.path.join(os.environ['BFANETWORKDIR'], 'node', 'keystore')]
        elif os.getenv('BFAHOME'):
            wheretolook += [os.path.join(os.environ['BFAHOME'], 'network', 'node', 'keystore')]
        if os.getenv('HOME'):
            wheretolook += [
                os.path.join(os.environ['HOME'], '.ethereum', 'keystore'),
                os.path.join(os.environ['HOME'], '.ethereum', 'keystore', 'test2'),
                os.path.join(os.environ['HOME'], '.ethereum', 'keystore', 'network')
            ]
        # Look for our pattern (or all files) in the directories
        matches = []
        ourregexp = '.*{}$'.format(pattern)
        for d in wheretolook:
            if os.path.exists(d):
                for f in os.listdir(d):
                    fn = os.path.join(d, f)
                    if os.path.isfile(fn):
                        if re.match(ourregexp, f.lower()):
                            matches += [os.path.join(d, f)]
        if pattern:
            if len(matches) == 0:
                # if a pattern was given but no matches were found,
                # return None
                return None
            else:
                # if a pattern was found but some matches were found,
                # return just the first one
                return matches[0]
        # If no pattern was given, return everything found, or the
        # empty list.
        return matches

    def unlock(self, accountname: str, passphrase: str):
        if os.path.isfile(accountname):
            self.keyfile = accountname
        else:
            self.keyfile = self.findkeyfilesindirectories(pattern=accountname)
        if self.keyfile is None:
            raise FileNotFoundError('The account was not found.')
        with open(self.keyfile) as fd:
            encrypted_key = fd.read()
            try:
                self.key = web3.Web3().eth.account.decrypt(encrypted_key, passphrase)
            except ValueError as exc:
                raise ValueError(
                    'The passphrase given for the account in file {} is incorrect, '
                    'or the input file is not a valid key file.'.format(self.keyfile)
                ) from exc
        # ADDRESS
        publickey = ecdsa.SigningKey.from_string(self.key, curve=ecdsa.SECP256k1).verifying_key
        pkbytestring = publickey.to_string() # returns bytestring
        ourhash = keccak.new(digest_bits=256)
        ourhash.update(pkbytestring)
        digest = ourhash.hexdigest()
        self.address = web3.Web3().toChecksumAddress('0x' + digest[-40:])

    def transact(self, *args, **kwargs):
        w3 = kwargs.get('web3')
        tx_details = self.calculate_tx_details(w3, *args, **kwargs)
        afunction = kwargs.get('function')
        txobj = tx_details
        if afunction:
            txobj = afunction(*args).buildTransaction(tx_details)
        receipt = self.txsignsendwait(w3, txobj)
        return receipt

    def txsignsendwait(self, w3: web3.Web3, txobj: dict):
        signedobj = self.signtx(txobj)
        txhashbytes = w3.eth.sendRawTransaction(signedobj.rawTransaction)
        self.nonce = self.nonce + 1
        receipt = w3.eth.waitForTransactionReceipt(txhashbytes)
        return receipt

    def signtx(self, tx: dict):
        signed = web3.Web3().eth.account.sign_transaction(tx, self.key)
        return signed

    def calculate_tx_details(self, w3: web3.Web3, *args, **kwargs) -> dict:
        # if kwargs has extragas=50000 then we add that number to the amount
        # of gas for the transaction
        afunction = kwargs.get('function')
        # Nonce may have increased on the network without us noticing
        # or past transactions may not yet have been mined (and a flooded
        # txpool).
        # This is a resonable fix (try not to send too many transactions)
        # If you use waitForTransactionReceipt() between each transaction
        # you will not have problems because of this.
        self.nonce = max(self.nonce, w3.eth.getTransactionCount(self.address))
        # Set minimum gasPrice to 1 Gwei, but allow more if the network says so.
        details = {
            'chainId': w3.eth.chain_id,
            'gasPrice': min(w3.toWei('1', 'gwei'), w3.eth.gasPrice),
            'nonce': self.nonce,
            'from': self.address,
        }
        for kw in [ 'to', 'value' ]:
            val = kwargs.get(kw)
            if val is not None:
                details[kw] = val
        # Ask for balance, so we can tell it, in case we have an exception
        balance = w3.eth.getBalance(self.address)
        try:
            if afunction:
                # Ask a node how much gas it would cost to deploy
                gas = afunction(*args).estimateGas(details)
            else:
                gas = w3.eth.estimateGas(details)
        except web3.exceptions.SolidityError as exc:
            raise web3.exceptions.SolidityError(
                'The Ethereum Virtual Machine probably did not like that.'
            ) from exc
        except ValueError as exc:
            raise ValueError(
                'Your transaction will fail. Maybe you are calling your '
                'contract wrong or are not allowed to call the funcion '
                'by a function modifier or '
                'your account may not have enough balance to work on this '
                'network. Your account balance is currently {} wei.'
                .format(balance)) from exc
        if kwargs.get('extragas') is not None:
            gas += kwargs.get('extragas')
        details['gas'] = gas
        return details


class Abi(list):

    def __str__(self):
        txt = ''
        for i in range(len(self)):
            elem = self.__getitem__(i)
            if type(elem) is not dict:
                continue
            if 'type' in elem:
                txt += "({}) ".format(elem['type'])
            name = ""
            if 'name' in elem:
                name = elem['name']
            if 'inputs' in elem:
                inputlist = list()
                for inputnum in range(len(elem['inputs'])):
                    _input = elem['inputs'][inputnum]
                    args = _input['type']
                    if 'name' in _input and _input['name'] != '':
                        args = "{}: {}".format(_input['name'], args)
                    inputlist.append(args)
                txt += "{}({})".format(name, ', '.join(inputlist))
            if 'outputs' in elem:
                outputlist = list()
                for outputnum in range(len(elem['outputs'])):
                    output = elem['outputs'][outputnum]
                    if 'name' in output and output['name'] != '':
                        outputlist.append("{}: {}".format(output['name'], output['type']))
                    else:
                        outputlist.append("{}".format(output['type']))
                txt += " -> ({})".format(', '.join(outputlist))
            if 'stateMutability' in elem:
                txt += ' [{}]'.format(elem['stateMutability'])
            txt += "\n"
        return txt
        # print(txt, file=sys.stderr)
        # return super(Abi, self).__str__()


class CompiledContract:

    solc_features = [
        'abi', 'asm', 'ast', 'bin', 'bin-runtime', 'compact-format',
        'devdoc', 'generated-sources', 'generated-sources-runtime',
        'hashes', 'interface', 'metadata', 'opcodes', 'srcmap',
        'srcmap-runtime', 'storage-layout', 'userdoc'
    ]
    dockerWorkdir = '/casa'

    def __init__(self, w3: web3.Web3, name: str):
        self.w3 = w3
        self.name = name
        self.json = None
        self.readtextfile()
        # Did read give us json, or should we compile it?
        if self.json is None:
            self.compile()

    def dockerargs(self):
        return [
            'docker', 'run',
            '--rm',
            # Mount our cwd as /casa
            '-v',
            '{}:{}'.format(os.getcwd(), self.dockerWorkdir),
            # Run as us inside the docker, so we have access to this directory
            '-u', str(os.getuid()),
            'bfaar/nodo',
            '/usr/local/bin/solc',
            '--evm-version', 'byzantium',
            # Get as many things dumped into our JSON as possible.
            # You never know when you'll need it, and space is cheap.
            '--combined-json', ','.join(self.solc_features),
            # We like optimized things.
            '--optimize',
            # File name of input file.
            '{}/contract.sol'.format(self.dockerWorkdir)
        ]

    def compile(self):
        # Make a copy with a fixed name
        # Mostly so people can use symlinks to the source files
        # which won't work when we call docker.
        candidate_sol = '{}.sol'.format(self.name)
        if os.path.exists(self.name):
            filename = self.name
        elif os.path.exists(candidate_sol):
            filename = candidate_sol
        else:
            filename = self.name
        with open(filename, 'r') as infile:
            with open('contract.sol', 'w') as outfile:
                outfile.write(infile.read())
        try:
            solc = subprocess.run(self.dockerargs(), stdout=subprocess.PIPE, check=True)
        finally:
            # Don't leave too much mess.
            os.remove('contract.sol')
        txt = solc.stdout
        output = txt.decode('utf-8')
        self.json = json.loads(output)
        self.writetextfile()

    def readtextfile(self):
        output = None
        for filename in ( '{}.compiled.json'.format(self.name), self.name ):
            if os.path.exists( filename ):
                with open(filename, 'rt', encoding='utf-8') as infile:
                    output = infile.read()
                    break
        if output is None:
            print("File not found.", file=sys.stderr)
            raise FileNotFoundError
        if len(output) < 2:
            print("The JSON file is too small ({} bytes read from {}).".format(len(output), filename), file=sys.stderr)
            raise NameError
        try:
            self.json = json.loads(output)
        except json.decoder.JSONDecodeError as exc:
            print("It was not possible to parse the JSON file (from is {}).".format(filename), file=sys.stderr)
            raise exc

    def writetextfile(self):
        filename = self.name + '.compiled.json'
        try:
            with open(filename, 'xt', encoding='utf-8') as outfile:
                outfile.write(json.dumps(self.json))
        except:
            os.remove(filename)
            raise

    def _where(self):
        # Inch our way closer and closer, all the time,
        # as long as we see labels which look vaguely familiar.
        # This may enable us to be more liberal in the JSON input
        # we receive from the file containing the cached compiled JSON.
        point = self.json
        for teststring in [
            'contracts',
            '{}/{}.sol:{}'.format(self.dockerWorkdir, 'contract', self.name),
            '{}/{}.sol:{}'.format(self.dockerWorkdir, self.name, self.name)
        ]:
            if type(point) is dict and teststring in point:
                point = point[teststring]
        return point

    def bytecode(self):
        self._where()
        return '0x' + self._where()['bin']

    def abi(self):
        # Old method which also works, but our own class has a nicer __str__:
        # return json.loads(self.json['contracts'][where]['abi'])
        where = self._where()
        if type(where) is str:
            where = json.loads(where)
        if (type(where) is dict) and 'abi' in where:
            where = where['abi']
        if type(where) is str:
            where = json.loads(where)
        return Abi(where)

    def instance(self, *args, **kwargs):
        addr = kwargs.get('address')
        if addr is None:
            account = kwargs.get('account')
            if account is None:
                raise KeyError('Either address or account must be speficied, in order to get an instance.')
            ourinstance = self.w3.eth.contract(abi=self.abi(), bytecode=self.bytecode())
            receipt = account.transact(*args, web3=self.w3, function=ourinstance.constructor)
            if receipt.status == 0:
                raise SystemError('Failed to deploy.')
            addr = receipt.contractAddress
        return self.w3.eth.contract(address=addr, abi=self.abi())
