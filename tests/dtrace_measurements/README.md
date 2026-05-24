# Mediciones con DTrace para validación cuantitativa

Esta carpeta conserva las mediciones realizadas para reforzar el punto 2.1 del informe de correcciones. El objetivo de estas pruebas no es demostrar una mejora general de rendimiento, sino aportar evidencia cuantitativa sobre el comportamiento del planificador y del módulo de inhibición de encolado.

Las mediciones se hicieron sobre FreeBSD 13.1 en una VM, usando DTrace y `openssl speed` como carga CPU-bound.

## Estructura

```text
tests/dtrace_measurements/
  4bsd/
  petri-inhibition-off/
  petri-inhibition-on/
utils/scripts/DTrace/
  context_switch_rate.d
  cpu_distribution.d
```

Cada escenario conserva:

- `kernel-info.txt`: kernel usado durante la medición.
- `context-switches.txt`: cambios de contexto observados por segundo.
- `openssl-speed.txt`: salida de `openssl speed` usada junto con `context-switches.txt`.
- `cpu-distribution.txt`: entradas `on-cpu` de `openssl` agrupadas por CPU.
- `openssl-speed-cpu-dist.txt`: salida de `openssl speed` usada junto con `cpu-distribution.txt`.

## Preparación

Confirmar que DTrace expone los probes del scheduler:

```bash
dtrace -l -n 'sched:::on-cpu'
dtrace -l -n 'sched:::off-cpu'
```

Crear las carpetas en la VM:

```bash
mkdir -p ~/dtrace-measurements/scripts
mkdir -p ~/dtrace-measurements/4bsd
mkdir -p ~/dtrace-measurements/petri-inhibition-off
mkdir -p ~/dtrace-measurements/petri-inhibition-on
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
