# Testing actual del scheduler Petri

Este documento resume el flujo de pruebas que reemplaza a los módulos `.ko`
históricos de `project_files/modules/`.

## Principio general

Las funcionalidades se prueban con kernels instalados en `/boot` y activadas por
`sysctl`, no cargando módulos externos con valores hardcodeados.

Branches principales:

- Base: `feature/petri-net-scheduler`
- Encendido/apagado: `testing/petri-net-scheduler_cpu-on-off-module`
- Monopolización: `testing/petri-net-scheduler_monopolize-cpu-module`

Kernels usados en la VM:

- Rescate/trabajo estable: `kernel-original`
- Testing on/off: `petri-onoff-test`
- Testing monopolize: `petri-monopolize-test`

## Verificar kernel activo

```sh
uname -a
sysctl kern.bootfile
```

Esperado para on/off:

```text
/boot/petri-onoff-test/kernel
```

Esperado para monopolize:

```text
/boot/petri-monopolize-test/kernel
```

## Evidencia de crash

Después de un panic o reboot inesperado:

```sh
ls -ltr /var/crash
tail -120 /var/log/messages
```

Si hay textdump:

```sh
tar -tf /var/crash/textdump.tar.N
tar -xOf /var/crash/textdump.tar.N panic.txt
tar -xOf /var/crash/textdump.tar.N ddb.txt | sed -n '1,220p'
tar -xOf /var/crash/textdump.tar.N msgbuf.txt | tail -160
```

Un panic con textdump es preferible a un cuelgue silencioso, porque deja
backtrace y estado del scheduler.

## Build/install de kernel de testing

Ejecutar el build desde `kernel-original` si el kernel de testing está inestable.

On/off:

```sh
cd ~/src/freebsd-src
git fetch origin
git switch testing/petri-net-scheduler_cpu-on-off-module
git pull --ff-only
make -j4 buildkernel KERNCONF=PI_KERNELCONF
su -
cd /usr/home/nicodrudi/src/freebsd-src
make installkernel KERNCONF=PI_KERNELCONF KODIR=/boot/petri-onoff-test
reboot
```

Monopolize:

```sh
cd ~/src/freebsd-src
git fetch origin
git switch testing/petri-net-scheduler_monopolize-cpu-module
git pull --ff-only
make -j4 buildkernel KERNCONF=PI_KERNELCONF
su -
cd /usr/home/nicodrudi/src/freebsd-src
make installkernel KERNCONF=PI_KERNELCONF KODIR=/boot/petri-monopolize-test
reboot
```

## Pruebas de encendido/apagado

Smoke test sin carga:

```sh
for c in 1 1 2 2 3 3; do
  date
  sysctl kern.sched_petri.cpu_toggle=$c
  sleep 3
done
dmesg | grep -E 'TOGGLE ACTIVE|Non sensitized|panic:' | tail -30
```

Inputs inválidos esperados:

```sh
sysctl kern.sched_petri.cpu_toggle=0
sysctl kern.sched_petri.cpu_toggle=4
```

Ambos deben devolver `Invalid argument`.

Carga alta sin toggles:

```sh
openssl speed -seconds 5 -multi 4 sha256
```

Carga alta con toggles:

```sh
openssl speed -seconds 5 -multi 8 sha256 >/tmp/onoff-test.log 2>&1 &
pid=$!

sleep 3
for c in 1 2 3 3 2 1; do
  echo "toggle cpu $c"
  sysctl kern.sched_petri.cpu_toggle=$c
  sleep 3
done

wait $pid
echo "openssl rc=$?"
tail -20 /tmp/onoff-test.log
dmesg | grep -E 'Non sensitized|panic:' | tail
```

Resultado esperado:

- `openssl rc=0`
- sin `Non sensitized`
- sin dump nuevo en `/var/crash`

## Pruebas de monopolización

El sysctl recibe `tid:cpu`.

```sh
sysctl kern.sched_petri.monopolize=<tid>:<cpu>
```

CPU válidas: `1`, `2`, `3`. CPU `0` se evita por su rol especial en el sistema.

Una forma simple de obtener TIDs durante carga:

```sh
openssl speed -seconds 20 sha256 >/tmp/monopolize-load.log 2>&1 &
pid=$!
sleep 1
procstat -at | grep openssl
```

Elegir un TID de la salida y activar monopolización:

```sh
sysctl kern.sched_petri.monopolize=<tid>:1
```

Para liberar, repetir el mismo comando:

```sh
sysctl kern.sched_petri.monopolize=<tid>:1
```

Validación recomendada:

- usar `htop` o `top -H` para observar distribución de carga;
- usar DTrace si está disponible:

  ```sh
  dtrace -s utils/scripts/DTrace/cpu_thread_analysis.d
  ```

## Criterio de éxito

Una prueba se considera saludable si:

- el comando de carga termina con exit code `0`;
- no hay nuevas líneas `Non sensitized`;
- no hay panic ni dump nuevo;
- el comportamiento observable coincide con el sysctl aplicado.

Si falla, conservar:

- comando exacto ejecutado;
- kernel activo (`uname -a`, `kern.bootfile`);
- `dmesg`;
- `/var/crash` y textdump/vmcore si existe.
