## Stamper.sol 

[Stamper.sol](https://gitlab.bfa.ar/blockchain/nucleo/blob/master/src/Stamper.sol) es un smart contract simple que puede utilizarse para una _timestamp authority_ o para cualquier caso en el que quiera registrarse cosas del tipo: 

* qué, quién, cuándo
* qué, dónde, cuándo
* quién, dónde, cuándo

Notar que el _cuándo_ definido más arriba se refiere a cuándo fue insertado en la _blockchain_, lo cual lo único que verifica es que el hecho, la cosa o la acción se realizaron o existían **antes** de eso. Si una aplicación requiere de una marca de tiempo específica (_fine grained_), como ser un registro de control de ingreso/egreso laboral, esto debería codificarse en el registro "qué" o "quién" y mantenerse _off-chain_.

El SC define una `struct stamp` que tiene:

* un hash llamado `object` (que representa un objeto arbitrario, que puede ser un archivo o cualquier otra cosa)
* una dirección llamada `stamper` (que identifica a la cuenta Ethereum -EOA- que invocó al SC para insertar este stamp)
* el número de bloque `blockno` (que contiene el número de bloque en el que se invocó al Sc para insertar este stamp)

El SC mantiene una lista de estas estructuras `stamplist` donde mantiene la información de todos los objetos _stampeados_.

En la primera posición de la lista (0), se guarda la información de la cuenta que instanció el SC y en qué bloque lo hizo.

Además mantiene dos arrays asociativos (_mappings_) que facilitan la búsqueda de stamps tanto por `object` (`hashobjects`) como por `stamper` (`hashstampers`).

Las funciones para invocar al SC son:

* `put ( [ lista de objects ] )` que recibe una lista de objects (puede ser uno solo) y genera un stamp para cada uno
* `getStampListPos ( posición )` que recibe una posición de la lista de stamps y devuelve el object correspondiente a esa posición
* `getObjectCount ( object )` que recibe un object y devuelve la cantidad de stamps que hay de ese object
* `getObjectPos ( object , pos )` que recibe un object y una posición de la lista para ese object y devuelve la posición correspondiente al stamp específico en la lista de stamps
* `getStamperCount ( stamper )` que recibe un stamper y devuelve la cantidad de stamps que realizó ese stamper
* `getStamperPos ( stamper , pos )` que recibe un stamper y una posición de la lista de ese stamper y devuelve la posición correspondiente al stamp específico en la lista de stamps

Esto permite fácilmente ubicar todos los stamps que hay de un object o todos los objects que haya enviado un stamper.

Un mismo object podría tener varios stamps (enviados por el mismo o diversos stampers).

En todos los casos, para cada stamp es fácil saber cuándo fue insertado en la blockchain.
