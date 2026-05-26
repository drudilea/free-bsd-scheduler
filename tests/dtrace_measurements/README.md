# Mediciones con DTrace para validación cuantitativa

Esta carpeta conserva las mediciones realizadas para reforzar el punto 2.1 del informe de correcciones. El objetivo de estas pruebas no es demostrar una mejora general de rendimiento, sino aportar evidencia cuantitativa sobre el comportamiento del planificador y de los módulos de inhibición de encolado y monopolización de núcleos.

Las mediciones se hicieron sobre FreeBSD 13.1 en una VM, usando DTrace y cargas CPU-bound.

## Estructura

```text
tests/dtrace_measurements/
  4bsd/
  petri-inhibition-off/
  petri-inhibition-on/
  petri-monopolization-off/
  petri-monopolization-on/
utils/scripts/DTrace/
  context_switch_rate.d
  cpu_distribution.d
  thread_cpu_distribution.d
  thread_context_switches.d
  reserved_cpu_foreign_threads.d
```

Cada escenario conserva:

- `kernel-info.txt`: kernel usado durante la medición.
- `context-switches.txt`: cambios de contexto observados por segundo.
- `openssl-speed.txt`: salida de `openssl speed` usada junto con `context-switches.txt`.
- `cpu-distribution.txt`: entradas `on-cpu` de `openssl` agrupadas por CPU.
- `openssl-speed-cpu-dist.txt`: salida de `openssl speed` usada junto con `cpu-distribution.txt`.

Los escenarios de monopolización conservan además:

- `thread-cpu-distribution.txt`: entradas `on-cpu` del TID observado, agrupadas por CPU.
- `reserved-cpu-foreign-threads.txt`: otros hilos observados en la CPU reservada.
- `procstat-after.txt`: estado del proceso de carga al finalizar la medición.
- `competing-openssl*.txt`: cargas concurrentes usadas para generar presión sobre el planificador.

## Preparación

Confirmar que DTrace expone los probes del scheduler:

```bash
dtrace -l -n 'sched:::on-cpu'
dtrace -l -n 'sched:::off-cpu'
```

Crear las carpetas en la VM:

```fish
mkdir -p ~/dtrace-measurements/scripts
mkdir -p ~/dtrace-measurements/4bsd
mkdir -p ~/dtrace-measurements/petri-inhibition-off
mkdir -p ~/dtrace-measurements/petri-inhibition-on
mkdir -p ~/dtrace-measurements/petri-monopolization-off
mkdir -p ~/dtrace-measurements/petri-monopolization-on
```

Durante las mediciones no conviene dejar `htop` u otros monitores activos en otra terminal, porque agregan actividad propia y pueden alterar cambios de contexto o migraciones.

## Scripts usados

Los scripts se encuentran en `utils/scripts/DTrace/`.

Para contar cambios de contexto:

```bash
dtrace -s ~/dtrace-measurements/scripts/context_switch_rate.d > $OUT/context-switches.txt
```

Para observar distribución por CPU:

```bash
dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d > $OUT/cpu-distribution.txt
```

Ambos scripts filtran por `execname == "openssl"`.

## Escenario 1: 4BSD puro

El kernel usado fue:

```text
/boot/kernel-4BSD/kernel
```

Guardar información del kernel:

```bash
set OUT ~/dtrace-measurements/4bsd
uname -a > $OUT/kernel-info.txt
sysctl kern.sched.name >> $OUT/kernel-info.txt
sysctl kern.bootfile >> $OUT/kernel-info.txt
```

Medición de cambios de contexto:

```bash
set OUT ~/dtrace-measurements/4bsd
dtrace -s ~/dtrace-measurements/scripts/context_switch_rate.d > $OUT/context-switches.txt
```

En otra terminal:

```bash
set OUT ~/dtrace-measurements/4bsd
/usr/bin/time -p openssl speed -seconds 20 -bytes 8192 sha256 > $OUT/openssl-speed.txt 2>&1
```

Al terminar `openssl`, cortar DTrace con `Ctrl+C`.

Medición de distribución por CPU:

```bash
set OUT ~/dtrace-measurements/4bsd
dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d > $OUT/cpu-distribution.txt
```

En otra terminal:

```bash
set OUT ~/dtrace-measurements/4bsd
/usr/bin/time -p openssl speed -seconds 20 -bytes 8192 sha256 > $OUT/openssl-speed-cpu-dist.txt 2>&1
```

## Escenario 2: Petri con inhibición inactiva

El kernel usado fue:

```text
/boot/kernel-petri-onoff/kernel
```

En este escenario no se activó `kern.sched_petri.cpu_toggle`.

Guardar información del kernel:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-off
uname -a > $OUT/kernel-info.txt
sysctl kern.version >> $OUT/kernel-info.txt
sysctl kern.bootfile >> $OUT/kernel-info.txt
sysctl kern.sched_petri.cpu_toggle >> $OUT/kernel-info.txt
```

Medición de cambios de contexto:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-off
dtrace -s ~/dtrace-measurements/scripts/context_switch_rate.d > $OUT/context-switches.txt
```

En otra terminal:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-off
/usr/bin/time -p openssl speed -seconds 20 -bytes 8192 sha256 > $OUT/openssl-speed.txt 2>&1
```

Medición de distribución por CPU:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-off
dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d > $OUT/cpu-distribution.txt
```

En otra terminal:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-off
/usr/bin/time -p openssl speed -seconds 20 -bytes 8192 -multi 4 sha256 > $OUT/openssl-speed-cpu-dist.txt 2>&1
```

## Escenario 3: Petri con CPU1 inhibida

El kernel usado fue:

```text
/boot/kernel-petri-onoff/kernel
```

La inhibición se activó sobre CPU1:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-on
sysctl kern.sched_petri.cpu_toggle=1
```

El `sysctl` funciona como disparador: al escribir el valor de CPU, alterna su estado dentro del módulo. En esta medición se inhibió CPU1 antes de ejecutar la carga.

Guardar información del kernel:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-on
uname -a > $OUT/kernel-info.txt
sysctl kern.version >> $OUT/kernel-info.txt
sysctl kern.bootfile >> $OUT/kernel-info.txt
sysctl kern.sched_petri.cpu_toggle >> $OUT/kernel-info.txt
```

Medición de cambios de contexto:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-on
dtrace -s ~/dtrace-measurements/scripts/context_switch_rate.d > $OUT/context-switches.txt
```

En otra terminal:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-on
/usr/bin/time -p openssl speed -seconds 20 -bytes 8192 sha256 > $OUT/openssl-speed.txt 2>&1
```

Medición de distribución por CPU:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-on
dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d > $OUT/cpu-distribution.txt
```

En otra terminal:

```bash
set OUT ~/dtrace-measurements/petri-inhibition-on
/usr/bin/time -p openssl speed -seconds 20 -bytes 8192 -multi 4 sha256 > $OUT/openssl-speed-cpu-dist.txt 2>&1
```

Al finalizar, CPU1 debe reactivarse con el mismo disparador:

```bash
sysctl kern.sched_petri.cpu_toggle=1
```

## Resumen de resultados

### Carga simple

La carga simple fue:

```bash
openssl speed -seconds 20 -bytes 8192 sha256
```

| Escenario                 | Throughput sha256 | Tiempo real | Cambios de contexto | Cambios de contexto/s |
| ------------------------- | ----------------: | ----------: | ------------------: | --------------------: |
| 4BSD puro                 |        348230.90k |     20.01 s |                  27 |                  1.35 |
| Petri inhibición inactiva |        371213.25k |     20.04 s |                  31 |                  1.55 |
| Petri CPU1 inhibida       |        394387.13k |     20.02 s |                  57 |                  2.85 |

Estos valores no deben leerse como una mejora de rendimiento. Sirven para mostrar que el kernel con Petri y el módulo de inhibición ejecutan la carga de forma estable y con una tasa de cambios de contexto comparable en orden de magnitud al 4BSD base.

### Distribución por CPU

Para comparar el efecto del módulo de inhibición se usó:

```bash
openssl speed -seconds 20 -bytes 8192 -multi 4 sha256
```

| Escenario                 |        CPU0 |       CPU1 |       CPU2 |       CPU3 | Total |
| ------------------------- | ----------: | ---------: | ---------: | ---------: | ----: |
| Petri inhibición inactiva | 133 (43.3%) | 58 (18.9%) | 61 (19.9%) | 55 (17.9%) |   307 |
| Petri CPU1 inhibida       | 129 (53.5%) |   0 (0.0%) | 65 (27.0%) | 47 (19.5%) |   241 |

La comparación relevante es entre los dos escenarios Petri. Con el módulo inactivo, CPU1 recibió trabajo ordinario de `openssl`. Con CPU1 inhibida, DTrace no registró entradas `on-cpu` de `openssl` sobre esa CPU durante la prueba, mientras la carga continuó ejecutándose sobre las CPUs restantes.

## Monopolización de CPU

Para la medición de monopolización se usó el kernel:

```text
/boot/kernel-petri-monopolized/kernel
```

El control del módulo recibe un par `tid:cpu`:

```fish
sysctl kern.sched_petri.monopolize=<tid>:<cpu>
```

La carga principal fue `single_thread_multiplier`, ubicado en `project_files/test_files/single_thread_multiplier`. El proceso observado fue:

```text
PID 983
TID 100402
CPU reservada 2
```

El TID se obtuvo con:

```fish
procstat -at | grep single_thread_multi
```

La activación del módulo fue:

```fish
sysctl kern.sched_petri.monopolize=100402:2
```

Durante la medición con monopolización activa se mantuvo una carga concurrente acotada con `openssl speed` y observación auxiliar con `htop`. El análisis formal se basa en las salidas de DTrace, no en la visualización de `htop`.

### Comandos DTrace usados

Antes de activar la monopolización se midió la distribución normal del TID observado:

```fish
set OUT ~/dtrace-measurements/petri-monopolization-off
set TARGET_TID 100402

timeout 22 dtrace -s ~/dtrace-measurements/scripts/thread_cpu_distribution.d $TARGET_TID > $OUT/thread-cpu-distribution.txt
```

También se tomó una medición de cambios de contexto del mismo TID:

```fish
set OUT ~/dtrace-measurements/petri-monopolization-off
set TARGET_TID 100402

timeout 22 dtrace -s ~/dtrace-measurements/scripts/thread_context_switches.d $TARGET_TID > $OUT/context-switches.txt
```

Luego se activó la reserva de CPU2 para ese TID:

```fish
set OUT ~/dtrace-measurements/petri-monopolization-on
set TARGET_TID 100402
set TARGET_CPU 2
set PAIR $TARGET_TID:$TARGET_CPU

sysctl kern.sched_petri.monopolize=$PAIR
```

Con la reserva activa se volvió a medir la distribución por CPU del TID observado:

```fish
timeout 22 dtrace -s ~/dtrace-measurements/scripts/thread_cpu_distribution.d $TARGET_TID > $OUT/thread-cpu-distribution.txt
```

En paralelo, se ejecutó una carga acotada con `openssl` para generar presión sobre el planificador sin bloquear la VM:

```fish
openssl speed -seconds 20 -bytes 8192 sha256 > $OUT/competing-openssl-1.txt 2>&1 &
```

Por último, se verificó si otros hilos ordinarios entraban en la CPU reservada. Este comando filtra CPU2 y excluye el TID reservado:

```fish
timeout 22 dtrace -s ~/dtrace-measurements/scripts/reserved_cpu_foreign_threads.d $TARGET_CPU $TARGET_TID > $OUT/reserved-cpu-foreign-threads.txt
```

El estado final del proceso observado se guardó con:

```fish
procstat -at | grep single_thread_multi > $OUT/procstat-after.txt
```

### Distribución del TID observado

| Escenario                 |       CPU0 |      CPU1 |       CPU2 |     CPU3 | Total |
| ------------------------- | ---------: | --------: | ---------: | -------: | ----: |
| Monopolización inactiva   | 16 (57.1%) | 5 (17.9%) |  6 (21.4%) | 1 (3.6%) |    28 |
| Monopolización sobre CPU2 |   0 (0.0%) |  0 (0.0%) | 259 (100%) | 0 (0.0%) |   259 |

La medición muestra un cambio claro en la residencia observada del hilo: con el módulo inactivo, el TID 100402 entró a ejecutar en distintas CPUs; con el módulo activo, todas las entradas `on-cpu` observadas para ese TID ocurrieron en CPU2.

### Otros hilos en la CPU reservada

El script `reserved_cpu_foreign_threads.d` se ejecutó filtrando CPU2 y excluyendo el TID 100402. Durante la ventana medida no registró otros hilos ordinarios entrando en CPU2:

```text
Final summary by execname
Final summary by tid
```

Este es el dato central para la validación del módulo: durante la prueba, la CPU reservada no recibió otros hilos ordinarios observables por DTrace, y el hilo elegido fue observado ejecutando únicamente en esa CPU.
