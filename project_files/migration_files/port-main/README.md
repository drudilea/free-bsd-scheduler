# Port del planificador Petri a FreeBSD main

Esta carpeta documenta el experimento de portar la rama base del planificador Petri desde FreeBSD 13.1 hacia `main`.

El objetivo de estos documentos es separar tres temas que suelen mezclarse:

1. Qué cambios funcionales de Petri ya existían en la rama 13.1.
2. Qué cambios fueron necesarios por diferencias reales de FreeBSD `main`.
3. Qué cuidados de integración conviene mantener antes de abrir un PR contra el `main` del repositorio del proyecto.

No se documentan aquí los módulos de encendido/apagado de CPUs ni de monopolización. Esos módulos deberían quedar en PRs separados, apoyados sobre la rama base Petri portada a `main`.

## Rama y alcance

Rama local del experimento:

```text
feature/petri-net-scheduler-main-port
```

Base:

```text
origin/main
```

Delta aplicado:

```text
origin/release13.1...feature/petri-net-scheduler
```

Archivos principales del port:

```text
.gitignore
sys/amd64/conf/PI_KERNELCONF
sys/conf/files
sys/kern/kern_thread.c
sys/kern/petri_global_net.c
sys/kern/sched_4bsd.c
sys/kern/sched_petri.c
sys/sys/proc.h
sys/sys/sched_petri.h
tools/sched/petri_addtoqueue.d
```

## Lectura recomendada

1. [00-scheduler.md](00-scheduler.md) Explica el funcionamiento de los métodos de `sched_4bsd.c` tocados por la tesis y cómo se relacionan entre sí.

2. [01-contexto.md](01-contexto.md) Explica por qué el merge completo contra `main` no era una buena señal y por qué se usó una aplicación del delta Petri.

3. [02-sched-throw.md](02-sched-throw.md) Explica con detalle el caso más importante: `sched_throw()`, `sched_ap_entry()` y quién está ejecutando el código del scheduler.

4. [03-cambios-reales.md](03-cambios-reales.md) Lista los cambios reales entre Petri sobre 13.1 y Petri sobre `main`, separando cambios funcionales de cambios de integración.

5. [04-viabilidad-pr.md](04-viabilidad-pr.md) Evalúa si el port es viable como PR contra el `main` del repositorio del proyecto y qué validaciones quedan pendientes.

## Resumen corto

La lógica central de Petri sobre 13.1 se pudo trasladar a `main` sin rediseño conceptual.

El conflicto sustantivo estuvo en `sys/kern/sched_4bsd.c`, especialmente por la separación moderna de FreeBSD entre:

```text
sched_throw(td)     -> sale un hilo real
sched_ap_entry()    -> arranca una CPU sin hilo saliente real
sched_throw_tail()  -> parte común que elige el siguiente hilo
```

El resto del trabajo fue principalmente de integración:

- preservar restricciones fuertes de FreeBSD: `pinned`, `bound` y afinidad;
- mantener `ADDTOQUEUE_FORCED` para evitar desincronización Petri/FreeBSD;
- rehacer `PI_KERNELCONF` desde el `GENERIC` actual de `main`;
- compilar los archivos Petri solo con `SCHED_4BSD`;
- evitar afectar kernels normales que no usan el planificador 4BSD.

## Relación con documentos existentes

Estos documentos complementan:

- `../PETRI_NET_PAGE_FAULT_FIX_ANALYSIS.md`
- `../PETRI_NET_FORCED_ADDTOQUEUE_TRACING.md`

La idea importante que se mantiene desde esos documentos es:

```text
Petri puede decidir cuando FreeBSD tiene libertad de política.
Petri no debe bloquear restricciones duras del kernel.
```

Por eso `ADDTOQUEUE_FORCED` no reemplaza al modelo original. Lo completa para casos donde FreeBSD debe encolar en una CPU concreta o dentro de un conjunto restringido.
