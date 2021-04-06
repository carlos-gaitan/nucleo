// 20180718 Robert Martin-Legene <robert@nic.ar>
// Time stamp authority

pragma solidity ^0.4.24;
      
contract TimeStampAuthority {
	// This mapping is almost an "associative array"
	mapping (uint256 => uint) private hashstore;

	// Stores hashes (256 bit uint) of a document in the mapping
	function put( uint256[] hasharray ) public {
                uint256 i = hasharray.length;
                while (i>0) {
                    i--;
                    uint256 h = hasharray[i];
                    if (hashstore[h] == 0) {
		        hashstore[h] = block.number;
                    }
                }
	}

	// Returns the block number in which the hash was first seen
	function get( uint256 hash ) public view returns (uint) {
		return hashstore[hash];
	}
}
