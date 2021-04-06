// Robert Martin-Legene <robert@nic.ar>
// vim:syntax:filetype=javascript:ai:sm

// SPDX-License-Identifier: GPL-2.0-or-later

// Copyright 2020 de la Direccion General de Sistemas Informaticos - Secretaria Legal y Tecnica - Nacion - Argentina.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/

pragma solidity >0.7.0;

// This contract is supposed to maintain a list of accounts authorized
// to control members of "the club" using a majority (n/1+1). We call
// that group the "council".
// For instance, could be useful for
// - a list of sealers
// - a board of directors
// - a local chess club
// - even outsourcing this kind of management from another smart contract.

contract Majority {
    // This struct contains a list of votes and who has voted for each victim/beneficiary.
    struct Vote {
        address             voter;      // Voter.
        address             victim;     // Whom are we voting about.
        uint                voteStart;  // When was the vote cast
        bool		    promotion;  // true=promotion, false=demotion
    }
    address[]       public  council;
    Vote[]          public  votes;
    uint            public  votetimeout = 604800; // default a week

    event               voteCast( address voter, address victim, bool promotion );
    event               adminChange( address admin, bool promotion );

    constructor( uint timeout )
    {
        if ( timeout >= 3600 )
            votetimeout         =   timeout;
        council.push( address(msg.sender) );
    }

    function    setTimeout( uint timeout ) public
    {
        if ( ! isCouncil(msg.sender) )
            revert("Only council members may use this function.");
        if ( timeout >= 3600 )
            votetimeout         =   timeout;
    }

    function    councilLength() public view returns (uint)
    {
        return council.length;
    }

    function    votesLength() public view returns (uint)
    {
        return votes.length;
    }

    // True or false if the subject is a member of the council.
    function    isCouncil( address subject ) public view returns (bool)
    {
        uint    i           =   council.length;
        while ( i-- > 0 )
            if ( subject == council[i] )
                return true;
        return false;
    }

    // Move all items in the list (after idx) one step closer to the
    // front of the list.
    function    _remove_vote( uint idx ) private
    {
        uint    max         =   votes.length;
        while ( ++idx < max )
            votes[idx-1] = votes[idx];
        // "pop" the end of the list, making the list shorter.
	votes.pop();
    }

    function    _remove_council_member( address exmember ) private
    {
        // Remove votes that the exmember has already cast.
        uint        i       =   votes.length;
        while ( i-- > 0 )
            if ( votes[i].voter == exmember )
                _remove_vote( i );
        // Move all items in the council list (after match) one step closer to the
        // front of the list.
        i                   =   council.length;
        while ( i-- > 0 )
        {
            if ( council[i] == exmember )
            {
                uint    idx =   i;
                uint    max =   council.length;
                while ( ++idx < max )
                    council[idx-1] = council[idx];
                // "pop" the end of the list, making the list shorter.
                council.pop();
                return;
            }
        }
    }

    // We run through the entire list of votes, checking if they fulfill the
    // requirements.
    function _promotedemote( address victim, bool promotion ) private
    {
        uint    numvotes        =   0;
        uint    majority        =   council.length / 2 + 1;
        uint    i               =   votes.length;
        while ( i-- > 0 )
            if ((    votes[i].victim    == victim )
                && ( votes[i].promotion == promotion )
            )
                numvotes++;
        // If we don't have enough votes to perform the actual promotion/demotion
        if ( numvotes < majority )
            return;
        // Is it a promotion or a demotion?
        if ( promotion )
            // Add victim to member list
            council.push( victim );
        else
            // Remove victim from member list
            _remove_council_member( victim );
        // Send notification
        emit adminChange( victim, promotion );
        // Remove the vote because the voting is complete.
        i                   =   votes.length;
        while ( i-- > 0 )
            if ((    votes[i].victim    == victim )
                && ( votes[i].promotion == promotion )
            )
            _remove_vote( i );
    }

    // You can call this for free and know if your promote call
    // will get accepted. Save the network, call this first.
    function mayVote( address voter, address victim, bool promotion ) public view returns (bool)
    {
        bool    voterIsOnCouncil    =   isCouncil( voter );
        bool    victimIsOnCouncil   =   isCouncil( victim );

        if ( ! voterIsOnCouncil )
            return false;

        // Can't promote someone who is already on the council
        if ( victimIsOnCouncil && promotion )
            return false;

        // Can't demote someone who is not a council member.
        if ( !victimIsOnCouncil && !promotion )
            return false;

        // See if he is trying to cast a vote already registered
        uint    ancient             =   block.timestamp - votetimeout;
        uint    i                   =   votes.length;
        while ( i-- > 0 )
        {
            if (   (votes[i].voter     == voter)
                && (votes[i].victim    == victim)
                && (votes[i].promotion == promotion)
                && (votes[i].voteStart > ancient)
            )
                return false;
        }
        return true;
    }

    // Calling this function will vote for adding an additional or
    // removing an existing member of council.
    // This requires n/2+1 votes (more than 50%).
    // The boolean must be true if you want to add a member
    // and false if you want to remove one.
    function vote( address victim, bool promotion ) public
    {
        if ( ! mayVote(msg.sender, victim, promotion))
            revert("That seems redundant or is otherwise not allowed.");
        // A little house keeping - if a vote is too old, then remove it
        uint    ancient                 =   block.timestamp - votetimeout;
        uint    i                       =   votes.length;
        while ( i-- > 0 )
            if ( votes[i].voteStart < ancient )
                _remove_vote( i );
        // End of house keeping
        // Store the vote
	votes.push(
            Vote(
                msg.sender,
                victim,
                block.timestamp,
                promotion
            )
        );
        // Send notification of the vote
        emit voteCast( address(msg.sender), victim, promotion );
        // See if we're ready to promote/demote anyone, based on the votes.
        _promotedemote( victim, promotion );

        // If we have no more council members, then we have no reason to continue living.
        if ( council.length == 0 )
            selfdestruct( msg.sender );
    }
}
