# Compilación de kernel

## Activar 4BSD como scheduler predeterminado

- Editar el archivo de configuración de kernel ubicado en `/usr/src/sys/amd64/conf`.
- El archivo se encuentra por defecto con el nombre `GENERIC`, pero en caso de haberlo modificado, editar este último.
- Se debe comentar la línea que indica el uso del `SCHED_ULE`, y agregar la línea para habilitar el uso de `SCHED_4BSD`

  ```bash
     #options SCHED_ULE   # ULE SCHEDULER
     options SCHED_4BSD   # 4BSD SCHEDULER
  ```

---

## Cómo compilar un kernel FreeBSD en modo debug:

1. Primero descargarse el código fuente del kernel de freeBSD en la carpeta `/usr/src` si es que no se encuentra disponible después de instalarlo.
2. Entrar en la carpeta del código fuente del kernel y copiar un config ya existente, posicionarse y hacer:

   ```bash
   cd /usr/src/sys/amd64/conf
   cp GENERIC PI_KERNELCONF
   ```

3. Editar el archivo PI_KERNELCONF para agregar las siguientes opciones:

   ```bash
   options KDB
   options DDB
   options KDB_UNATTENDED
   options GDB
   ```

4. Volver a la carpeta `/usr/src` y como root ejecutar los siguientes comandos:

   ```bash
   make buildkernel KERNCONF=PI_KERNELCONF
   make installkernel KERNCONF=PI_KERNELCONF
   ```

5. Una vez compilado resetear y ya está listo para debuggear el kernel. Para comenzar el debug ejecutar:

   ```bash
   sysctl debug.kdb.enter=1
   ```

---

## Recompilado rápido del Kernel (Súper Útil)

Existen una serie de banderas que pueden utilizarse para realizar un recompilado
más rápido del kernel. Estas son las siguientes:

```bash
make NO_KERNELCLEAN=yes NO_KERNELDEPEND=yes MODULES_WITH_WORLD=yes buildkernel KERNCONF=PI_KERNELCONF
```

- **NO_KERNELCLEAN:** evita que se eliminen los archivos ya compilados
  que no necesitan ser recompilados
- **NO_KERNELDEPEND:** evita revisar el árbol de dependencias. Utilizar
  cuando no se haya realizado ningún cambio en un header.
- **MODULES_WITH_WORLD:** evita el recompilado de lo módulos del kernel.

---

## Bibliografía:

- [KERNEL DEBUG](https://www.freebsd.org/doc/en_US.ISO8859-1/books/developers-handbook/kerneldebug-online-ddb.html)
- [FreeBSD kernel debugging ](http://chetanbl.blogspot.com.ar/2011/11/freebsd-kernel-module-debugging.html)
- [Install FreeBSD kernel sources ](http://unix.stackexchange.com/questions/204956/how-do-you-install-the-freebsd10-kernel-sources)
- [Grow FreeBSD Partition ](https://docs.freebsd.org/en/books/handbook/disks/#disks-growing)
