# Blockchain Federal Argentina

## Sitio web: https://www.bfa.ar/
## Repositorio: https://gitlab.bfa.ar/blockchain/nucleo.git

Este repositorio contiene lo nececario para instalar un "nodo BFA" (nodo sellador, nodo gateway, nodo transaccional "etc", son casi iguales).

Esta guía debería funcionar en Debian o sus derivados. Testeado en *Debian* y *Ubuntu server* sin la GUI instalada en ninguno de ellos.

([Capturas de pantallas instalando un Ubuntu 18.04](https://gitlab.bfa.ar/blockchain/nucleo/wikis/Instalando-Ubuntu-Server-18.04))  
([Capturas de pantallas instalando un Debian 9.5](https://gitlab.bfa.ar/blockchain/nucleo/wikis/Instalando-debian-9.5))

1. Instalá `git`
   - como root: `apt install git`
2. Cloná el repositorio oficial BFA
   - `git clone https://gitlab.bfa.ar/blockchain/nucleo.git bfa`
3. Ejecutá el script de instalación. Esto cambiará algunas configuraciones en tu sistema. Si te preocupa (¿debería?), podés ejecutar este escript paso a paso manualmente.
   - como root: `bfa/bin/installbfa.sh`  
   - te va a preguntar si queres conectarte a la red de `produccion` o de `prueba (test2)`  
   Van a aparecer varios **warnings** mientras se instala web3. Esto parece ser "normal". Ignorarlo no parece causar problemas.
4. Cambiá al usuario `bfa`
   - como root: `su - bfa`
5. <del>Crea una cuenta</del> // solamente los 20-30 nodos selladores necesitan una cuenta en el nodo
   - <del>como bfa: `admin.sh account`</del>
6. Comenzá la sincronización. **Esto puede llevar un rato largo** (este script se ejecuta automáticamente cuando se reinicia el sistema).
   - como bfa: `start.sh`
7. `localstate.pl` muestra el estado actual del nodo.
8. Monitoreá los logs con `bfalog.sh`. Apretá CTRL-C en cualquier momento para detener el `tail -f`.
9. Cambiá la configuración de tu nodo usando `admin.sh syncmode`
   - Hacé esto antes de haber sincronizado mucho en el paso anterior, ya que esto podría remover todos los datos de la cadena que hayas bajado y reiniciar la sincronización de la cadena.
10. Esperá a aque termine de sincronizar
11. Herramientas simples super básicas (más bien pruebas de concepto, para inspirar a los programadores):
    - `explorer.sh` : Sigue el bloque más nuevo "*lastest*" por default, pero podés especificar un número de bloque cualquiera como argumento, por ejemplo `explorer.sh 0` permite ver el génesis (bloque 0).
    - `walker.pl` : También toma un número de bloque para iniciar. Sigue esperando nuevos bloques.
    - `sealerwatch.pl` : Mira cuando los selladores firman.

Hay otros programas "interesantes" en los directorios `bin/` y `src/`,
pero para los desarrolladores, el branch `dev` es más intersante y tambien el
([repositorio contrib](https://gitlab.bfa.ar/blockchain/contrib)).

**Puede tardarse alrededor de una hora conectarse la primera vez. En el log no se ve nada. Hay que tener paciencia.**

### network_id

Se puede consultar el ID de la red con el comando RPC `net.getVersion` o/y `net.version`.

Red de producción (nombre: network): 
47525974938 (0xb10c4d39a)

Red de pruebas (nombre: test2network):
55555000000 (0xcef5606c0)

### chainId

Normalmente chainId es el mismo numero que network_id, pero no es necesario. En BFA son distintos.
Se puede consultar el chainId con el comando RPC `eth.chainId`.

Red de producción (network): 
200941592 (0xbfa2018)

Red de pruebas (test2network):
99118822 (0x5e86ee6)

## start.sh

Inicia un nodo para vos en la red BFA Ethereum.

## attach.sh

Te conecta a la línea de comandos (CLI) del `geth` que está corriendo en tu máquina local (falla si no hay un `geth` corriendo).

## explorer.sh

Scritp simple para mirar bloques

## walker.pl

Muestra una línea por bloque que se va sellando en la red, luego espera hasta el siguiente bloque.

## sealerwatch.pl

Muestra cuando los selladores sellan bloques. Tiene amarillo y colorado para mostrar cuando algo no es optimo.

## rewind.sh

Si tu nodo local parece clavado y sigue conectado, podés probar esta 
herramienta que va a regroceder algunos bloques en la cadena y tratar
de retomar desde allí. Realmente no debería pasar, pero hemos visto
algunas veces, mientras había pocos selladores, que algunos nodos se
trababan en un *side fork*.

## log.sh

Toma `stdin` y lo rota sobre una cantidad limitada de archivos de log.
Mandamos la salida de `geth` a través de un *pipe* a `log.sh` para poder
leer el log.

## sendether.sh

Script para mandar Ether a alguien.

## MasterDistiller.js

Administra un *smart contract* de la Destilería ya desplegado. Va a mostrar
las cuentas registradas y la cantidad de Ether configurada ("*allowance*") de
cada una de ellas.

## unlock.js

Debloqua las cuentas del sistema (vease tambien `monitor.js`). Si una cuenta
tiene clave, se puede poner la clave con este script.

## monitor.js

Esto se corre desde `cron.sh`. Cada minuto actualizará el archivo
`network/status` que muestra información del estado del nodo muy básica.
Tambien habilita sellar/minar si la cuenta (eth.accounts[0]) esta permitido
segun la red. Desbloqua cuentas si no tienen passwords.

## compile.and.deploy.contract

Compila y despliega un *smart contract* a la blockchain. Debe haber una cuenta (*account*) local que tenga suficiente Ether para pagar por la transacción.

Argumento 1 es el nombre de archivo del *smart contract* a compilar.

Ejemplo: `compile.and.deploy.contract src/TimestampAuthority.sol`

## localstate.pl

Muestra varias detalles del entorno local.
