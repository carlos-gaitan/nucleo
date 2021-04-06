# libbfa.py

## Library for Python3 to talk to your local POA node.

```python
#!/usr/bin/env python3

import libbfa

bee = '0xbee0966BdC4568726AB3d3131b02e6255e29285D'
d18 = '0xbfA2c97c3f59cc929e8fEB1aEE2Aca0B38235d18'
```
Which network do you want to connect to?  
If you want to connect to an open/public node
you can specify `bfa2018` or `test2`. If you
want to connect to another (your own?) node,
you can specify the URL, or give a `Provider`
```python
bfa = libbfa.Bfa('test2')
bfa = libbfa.Bfa('http://localhost:8545')
```
Find the file locally which matches the name
mentioned in the first argument. '0x' is
removed before case-insensitive matching
is performed.  
Second argument (if specified) is the password.
```python
acct = libbfa.Account(bee)
acct = libbfa.Account(bee, 'pepe')
```
Create a skeleton for the 'factory'  
The name of the contract is given in the second
argument and must be a contract in the current
directory (not symlinked).  
If the contract is not compiled locally already
your local docker installation is used (must have).  
```python
Factory = libbfa.CompiledContract(bfa.w3, 'Majority')
```
### Deploy a new contract.

If no address is given, an
account (object) must be given, which will be used
to deploy a new instance of the contract on the
blockchain. *You usually only want to deploy a
contract one time.* (If you need multiple tries,
consider using the test-net).

If you choose to deploy a new contract, remember to
give the arguments that the contract wishes for it's
constructor **or you will get an absurd error message
about being out of gas**.

The number `86400` in this example is the desired
argument for deployment of this particular contract
that the smart contract will get passed to it's
constructor. This contract takes a `uint256`.

Once you succesfully have a deployed contract in the
network, you can find it's address in the receipt's
`.address` field. Make a note of that address,
because you must use that address for all
subsequent calls to reach that contract.

```python
newdeployment = Factory.instance(86400, account=acct)
contractaddress = newdeployment.address
print('Your contract is deployed at address ' + contractaddress)
newdeployment = None
```

Now it is deployed and we can pretend that happened
many days ago. The 4 lines above need not be repeated,
but the others do (libbfa, account and Factory setup).

Now, we'll create a new reference to the same contract.

Since our contract is deployed now, we
see how to reference the already deployed
contract.
```python
samecontract = Factory.instance(address=contractaddress)
# better variable name for later
majority=samecontract
```
call()s are free (no gas needed) and local to the node
you are working with.
They require no account, no signature, no
transaction and are almost instant.
```python
print('Council length: {}'.format(majority.functions.councilLength().call()))
print('Votes length: {}'.format(majority.functions.votesLength().call()))
print('isCouncil bee: {}'.format(majority.functions.isCouncil(bee).call()))
print('mayVote bee,d18,True: {}'.format(majority.functions.mayVote(bee,d18,True).call()))
print('mayVote bee,d18,False: {}'.format(majority.functions.mayVote(bee,d18,False).call()))
print('mayVote d18,bee,True: {}'.format(majority.functions.mayVote(d18,bee,True).call()))
```
Transactions form part of the blockchain and must be mined
by the sealers, so they take a little longer to complete.
They are signed by the sender account.

Your *kwargs* must reference a configured `web3` (probably the one from
`libbfa`), and also give a reference to the `function` that you are
going to send a transaction to.

The first arguments (all the *args*) will be sent to the function in
the smart contract, so make sure the match in type.

The function name is a funny mix between Python variable names you
have defined yourself, plus functions which have arisen from the smart
contracts ABI.

```python
r = acct.transact(d18, False, web3=bfa.w3, function=majority.functions.vote)
print(r)
```

### Error examples

<a name="argument-after-asterisk-must-be-an-iterable-not-nonetype"></a>
argument after * must be an iterable, not NoneType

```python
# Error text: argument after * must be an iterable, not NoneType
print(majorcontr.functions.councilLength.call())
# Fix
print(majorcontr.functions.councilLength().call())
```

<a name="argument-after-asterisk-must-be-an-iterable-not-nonetype"></a>
gas required exceeds allowance
```python
# Error text: ValueError: {'code': -32000, 'message': 'gas required exceeds allowance (8000000)'}
```
Tu transacción va a fallar.
