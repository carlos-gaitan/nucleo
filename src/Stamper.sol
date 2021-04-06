// 20190401 Robert Martin-Legene <robert@nic.ar>
// Stamper
// vim:filetype=javascript

pragma solidity ^0.5.2;
      
contract Stamper {
    struct          stamp {
        uint256         object;
        address         stamper;
        uint256         blockno;
    }
    stamp[]         stamplist;

    // Mapping de objects stampeados a la stamplist
    mapping ( uint256 => uint256[] )  hashobjects;

    // Mapping de cuentas que stampean (stampers) a la stamplist
    mapping ( address => uint256[] )  hashstampers;

    constructor() public {
        // No queremos que haya stamps asociados a la posicion 0 (== false)
        // entonces guardamos ahi informacion de quien creo el SC y en que bloque
        stamplist.push( stamp( 0, msg.sender, block.number) );
    }

    // Stampear una lista de objects (hashes)
    function put( uint256[] memory objectlist ) public {
        uint256     i           =   0;
        uint256     max         =   objectlist.length;
        while ( i<max )
        {
            uint256     h       =   objectlist[i];
                    // stamplist.push devuelve la longitud, restamos 1 para usar como indice
            uint256     idx     =   stamplist.push( stamp( h, msg.sender, block.number ) ) - 1;
            hashobjects[h].push( idx );
            hashstampers[msg.sender].push( idx );
            i++;
        }
    }

    // devuelve un stamp completo (object, stamper, blockno) de la lista
    function getStamplistPos( uint256 pos ) public view returns ( uint256, address, uint256 )
    {
        return  (stamplist[pos].object, stamplist[pos].stamper, stamplist[pos].blockno );
    }
    
    // devuelve la cantidad de stamps que hay de este object
    function getObjectCount( uint256 object ) public view returns (uint256) 
    {
        return hashobjects[object].length;
    }

    // devuelve la ubicacion en la stamplist de un stamp especifico de este object
    function getObjectPos( uint256 object, uint256 pos ) public view returns (uint256)
    {
        return hashobjects[object][pos];
    }

    // devuelve la cantidad de stamps que realizo este stamper
    function getStamperCount( address stamper ) public view returns (uint256) 
    {
        return hashstampers[stamper].length;
    }

    // devuelve la ubicacion en la sstamplist de un stamp especifico de este stamper
    function getStamperPos( address stamper, uint256 pos ) public view returns (uint256)
    {
        return hashstampers[stamper][pos];
    }
}
