// vim:filetype=javascript
pragma solidity ^0.5;

contract Distillery {
    address payable     owner;
    struct      Allowances {
        address payable beneficiary;
        uint            topuplimit;
    }
    Allowances[]        thelist;
    // We use distpos to remember where we were stopped processing last time
    // we were called. The idea is, that if we have too many accounts to take
    // care of, and too little gasleft, then we stop before we run out of
    // gas, since that would undo all the transactions we had already handled.
    // Also, we don't want to favour anyone in particular in the list, such
    // that some would have first priority in getting ether at every invocation
    // So we continue checking the list from the same place where we left off
    // at the previous invocation of distribute()
    uint                distpos;

    event               distributeStartedBy( address activator );
    event               setAllowance( address subject, uint amount );
    event               xfrAllowance( address subject, uint amount );

    constructor() public payable {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require( msg.sender == owner );
        _;
    }
    // Using this function, you can find out how long thelist is.
    function numberOfBeneficiaries() public view returns ( uint ) {
        return thelist.length;
    }
    // Using this function, you get the address and topuplimit at a given position in thelist.
    function atPosition( uint idx ) public view returns ( address, uint ) {
        require( idx <= thelist.length, "There are not that many addresses in the list." );
        return (thelist[idx].beneficiary,thelist[idx].topuplimit);
    }
    // Returns a position +1 of where an address can be found in thelist.
    // Or returns 0  if the address is not found in thelist.
    // 0 : not found
    // 1 : first position
    function _beneficiaryPosition( address payable beneficiary ) internal view returns ( uint ) {
        uint    pos         =   thelist.length;
        while ( pos-- > 0 )
            if ( beneficiary == thelist[pos].beneficiary )
                return pos+1;
        return 0;
    }
    // This function returns the "allowance" that a given address is set to.
    // Using this function, you don't have to cycle through atPosition() until
    // you find the address you want to know about.
    function    getEtherAllowance( address payable beneficiary ) public view returns (uint256) {
        uint    pos         =   _beneficiaryPosition( beneficiary );
        if ( pos == 0 )
            return 0;
        return thelist[pos-1].topuplimit;
    }
    // This admin (ownerOnly) function allows the creator of the contract to
    // add/change/delete "allowances" per address.
    function    setEtherAllowance( address payable beneficiary, uint256 topuplimit ) public onlyOwner {
        uint    pos         =   _beneficiaryPosition( beneficiary );
        // Not found and trying to delete beneficiary? Just return immediately.
        if ( pos == 0 && topuplimit == 0 )
            return;
        emit    setAllowance( beneficiary, topuplimit );
        // not found
        if ( pos == 0 )
        {
            if ( topuplimit > 0 )
                // Add the address to thelist because it was not already there
                thelist.push( Allowances(beneficiary,topuplimit) );
            return;
        }
        // Now use a properly zero-indexed pos
        pos--;
        //
        if ( topuplimit > 0 ) {
            // Simple update the topuplimit of this address
            thelist[pos].topuplimit =   topuplimit;
            return;
        }
        // The beneficiary is set to have 0 Ether, so we
        // delete the beneficiary from the list
        uint    i                   =   pos;
        while ( i++ < thelist.length )
            thelist[i-1] = thelist[i];
        // Shorten the list
        thelist.length--;
        // If distpos was past the position that we removed,
        // then move that back one.
        if ( distpos >= pos )
            distpos--;
    }
    function    selfDestruct() public onlyOwner {
        selfdestruct( owner );
    }
    function    mayDistribute() public view returns ( bool )
    {
        return msg.sender == owner;
    }
    function distribute() external {
        require( mayDistribute(), "You are not authorized to activate the distribution functionality." );
        emit    distributeStartedBy( msg.sender );
        // Is there anything to do at all
        uint    listlength          =   thelist.length;
        if ( listlength == 0 )
            return;
        // Has the list gotten shorter since we we were last time?
        // This shouldn't happen, but it's better to be safe than to be sorry.
        if ( distpos >= listlength )
            distpos                 =   0;
        uint    wheretostop         =   distpos;
        while ( gasleft() > 54321 ) {
            // Did we get to the end of the list, then start over
            if ( ++distpos >= listlength )
                distpos             =   0;
            uint    blockchainbalance = thelist[distpos].beneficiary.balance;
            uint    topuplimit      =   thelist[distpos].topuplimit;
            uint    diff            =   topuplimit - blockchainbalance;
            // Don't top up anyone, if they still more than 90% of their allowance.
            if ( blockchainbalance > topuplimit*9/10 )
                diff                =   0;
            if ( diff > 0 )
            {
                // we use send() instead of transfer(), because
                // transfer() can throw(), and we don't want
                // to stop processing because of a single error.
                // -
                // Use || true to avoid warnings from the compiler.
                emit    xfrAllowance( thelist[distpos].beneficiary, diff );
                thelist[distpos].beneficiary.send( diff ) || true;
            }
            if ( wheretostop == distpos )
                return;
        }
    }
    function () external payable {
    }
}
