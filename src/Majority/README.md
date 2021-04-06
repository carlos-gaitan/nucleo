# Majority

This contract maintains a list of accounts authorized
to control members of "the club" using a majority (n/1+1).
We call that group the "council".

For instance, could be useful for
  * a list of sealers
  * a board of directors
  * a local chess club
  * even outsourcing this kind of management from another smart contract.

There are a few functions that can be used to see the contents of the
data structures used. Usually, you probably only need to **vote()** and
to ask if some account **isCouncil()**

See the test suite for examples of how to extract information from the
different datastructures, if you feel you really need that.

## Events

### voteCast

**voteCast( address voter, address victim, bool promotion )**

Gives the address of who voted, who they voted for and if it should
be a promotion (true) or demotion (false).

A promotion means to become a member of the council.

A demotion means to be removed from the list of council members.

### adminChange

**adminChange( address admin, bool promotion )**

This event is emitted when an address has received enough votes to be
promoted or demoted and that action is taken.

## Functions

### constructor

**constructor( uint timeout )**

This function is called when the contract is getting deployed.

The deploying address automatically becomes the only council member and
needs to vote to include other's. The contract creator has no special
powers other than other council members, and as such can be voted out
and lose all control over the contract.

If you specify an integer when deploying the contract, you can change
the time it takes for a vote to time out. The timeout can not be set
lower than one hour. The default is 7 days.

### setTimeout

**setTimeout( uint timeout )**

Change the timeout (in seconds) for validity of votes cast.
Any council member can change the timeout.
The timeout can not be set lower than one hour.

### councilLength

**councilLength()**

Returns a uint telling how many entries are in the council list.

### votesLength
    
**votesLength()**

Returns a uint telling how many structs are in the votes array.

### isCouncil

**isCouncil( address subject )**

Returns true or false whether the given address is a member of the
council.

### mayVote

**mayVote( address voter, address victim, bool promotion )**

Returns true or false if a certain address may vote a certain vote for
a certain address.

### vote

**vote( address victim, bool promotion )**

Performs actual voting on including (true) or removing (false) an address
from the council.

If the final member of the council votes to remove itself, the contract
will self-destruct.
