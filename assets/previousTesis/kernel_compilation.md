# Compilación de kernel

## Cómo compilar un kernel FreeBSD en modo debug:

1. Primero descargarse el código fuente del kernel de freeBSD en la carpeta `/usr/src` si es que no se encuentra disponible después de instalarlo.
2. Entrar en la carpeta del código fuente del kernel y copiar un config ya existente, posicionarse y hacer:

   ```bash
   cd /usr/src/sys/amd64/conf
   cp GENERIC KERNELCONF
   ```

3. Editar el archivo KERNELCONF para agregar las siguientes opciones:

   ```bash
   options KDB
   options DDB
   options KDB_UNATTENDED
   options GDB
   ```

4. Volver a la carpeta `/usr/src` y como root ejecutar los siguientes comandos:

   ```bash
   make buildkernel KERNCONF=KERNELCONF
   make installkernel KERNCONF=KERNELCONF
   ```

5. Una vez compilado resetear y ya está listo para debuggear el kernel. Para compezar el debug ejecutar:

   ```bash
   sysctl debug.kdb.enter=1
   ```

---

## Cómo debuggear el kernel de FreeBSD utilizando dos VMs

1. Descargarse el código fuente utilizado para compilar el kernel de la VM1 (Debugger Source) en la VM2 (Debugger Target), mediante el siguiente comando:

   ```bash
   cd /usr/src
   fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/{RELEASE-VERSION}/src.txz
   tar -C / -xzvf src.txz
   ```

En el caso de querer debuggear el código existente, se deberá hacer clone del repositorio actual y hacer un checkout de la rama correspondiente al proyecto final.

2. Dirigirse a la primera VM y seteas la siguiente configuración en serial ports:

https://drive.google.com/file/d/14d5CjhLVKxIeaJFO9jwsHE5b1ukU7zb1/view?usp=sharing

Tener en cuenta que debe estar descheckeada la opción de conectar a pipe existing ya que queremos que cree uno nuevo.

3. Dirigirse a la segunda VM y setear la configuración de la misma manera sólo que se debe seleccionar la opción de conectarse al pipe existente.

https://drive.google.com/file/d/1iHPMtNBKfwwwOTP2kE8zJXiQBoU7SuDU/view?usp=sharing

4. Para realizar prueba se prenden las dos máquinas virtuales y en la VM1 escribir:

   ```bash
   echo “Test String” >> /dev/cuau0
   ```

   Y en la máquina VM2 se ejecuta el comando:

   ```bash
   cat /dev/cuau0
   ```

   Y se debería poder leer Test String.

5. En la VM2 editar el archivo ubicado en `/boot/device.hints` para que se encuentre la siguiente línea:

   ```bash
   hint.uart.0.flags="0x80"
   ```

   Y ejecutar los siguientes comandos:

   ```
   cd /usr/obj/usr/src/sys/KERNELCONF
   make gdbinit
   kgdb -r /dev/cuau0 ./kernel.debug
   ```

6. En la VM1 ejecutar el siguiente comando para comenzar el debugging:

   ```bash
   sysctl debug.kdb.enter=1
   db> gdb
   ```

7. Para debuggear en la VM2 utilizar n(next), s(step), bt(break), c(continue)

\*Nota: Tener en consideración que se deben copiar los archivos de `/usr/obj` en la VM1 hacia la VM2 para poder debuggear el kernel.

### Comandos útiles a la hora de debuggear:

| Comando       | Explicación                                                                   |
| ------------- | ----------------------------------------------------------------------------- |
| break {where} | Agrega un breakpoint, puede ser un nombre de método, o una línea de archivo   |
| continue      | Continúa la ejecución hasta el próximo breakpoint                             |
| next          | Ejecuta la línea actual (Mismo nivel de produnidad)                           |
| step          | Ejecuta la línea actual ingresando al método que se está convocando (Step-in) |
| info locals   | Imprime variables locales                                                     |
| print \*dato  | Imprimir estructuras de datos                                                 |
| frame         | Te dice donde estas parado en el programa (Stack Frame)                       |

### Recompilado rápido del Kernel (Súper Útil)

Existen una serie de banderas que pueden utilizarse para realizar un recompilado
más rápido del kernel. Estas son las siguientes:

```bash
make NO_KERNELCLEAN=yes NO_KERNELDEPEND=yes
MODULES_WITH_WORLD=yes buildkernel KERNCONF=KERNELCONF
NO
```

- **NO_KERNELCLEAN:** evita que se eliminen los archivos ya compilados
  que no necesitan ser recompilados
- **NO_KERNELDEPEND:** evita revisar el árbol de dependencias. Utilizar
  cuando no se haya realizado ningúun cambio en un header.
- **MODULES WITH WORLD:** evita el recompilado de lo módulos del kernel.

### Bilbiografía:

- [KERNEL DEBUG](https://www.freebsd.org/doc/en_US.ISO8859-1/books/developers-handbook/kerneldebug-online-ddb.html)
- [FreeBSD kernel debugging ](http://chetanbl.blogspot.com.ar/2011/11/freebsd-kernel-module-debugging.html)
- [Install FreeBSD kernel sources ](http://unix.stackexchange.com/questions/204956/how-do-you-install-the-freebsd10-kernel-sources)
