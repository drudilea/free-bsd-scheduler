# Port del planificador Petri a FreeBSD main

Esta carpeta documenta el experimento de portar la rama base del planificador Petri desde FreeBSD 13.1 hacia `main`.

El objetivo de estos documentos es separar tres temas que suelen mezclarse:

1. Que cambios funcionales de Petri ya existian en la rama 13.1.
2. Que cambios fueron necesarios por diferencias reales de FreeBSD `main`.
3. Que cuidados de integracion conviene mantener antes de abrir un PR contra el `main` del repositorio del proyecto.

No se documentan aqui los modulos de encendido/apagado de CPUs ni de monopolizacion. Esos modulos deberian quedar en PRs separados sobre la rama base Petri portada a `main`.

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

1. [00-scheduler.md](00-scheduler.md) Explica el funcionamiento de los metodos de `sched_4bsd.c` tocados por la tesis y como se relacionan entre si.

2. [01-contexto.md](01-contexto.md) Explica por que el merge completo contra `main` no era una buena senial y por que se uso un port por delta.

3. [02-sched-throw.md](02-sched-throw.md) Explica con detalle el caso mas importante: `sched_throw()`, `sched_ap_entry()` y quien esta ejecutando el codigo del scheduler.

4. [03-cambios-reales.md](03-cambios-reales.md) Lista los cambios reales entre Petri sobre 13.1 y Petri sobre `main`, separando cambios funcionales de cambios de integracion.

5. [04-viabilidad-pr.md](04-viabilidad-pr.md) Evalua si el port es viable como PR contra el `main` del repositorio del proyecto y que validaciones faltan.

## Resumen corto

La logica central de Petri sobre 13.1 se pudo trasladar a `main` sin redisenio conceptual.

El conflicto sustantivo estuvo en `sys/kern/sched_4bsd.c`, especialmente por la separacion moderna de FreeBSD entre:

```text
sched_throw(td)     -> sale un hilo real
sched_ap_entry()    -> arranca una CPU sin hilo saliente real
sched_throw_tail()  -> parte comun que elige el siguiente hilo
```

El resto del trabajo fue principalmente de integracion:

- preservar restricciones fuertes de FreeBSD: `pinned`, `bound` y afinidad;
- mantener `ADDTOQUEUE_FORCED` para evitar desincronizacion Petri/FreeBSD;
- rehacer `PI_KERNELCONF` desde el `GENERIC` actual de `main`;
- compilar los archivos Petri solo con `SCHED_4BSD`;
- evitar afectar kernels normales que no usan el planificador 4BSD.

## Relacion con documentos existentes

Estos documentos complementan:

- `../PETRI_NET_PAGE_FAULT_FIX_ANALYSIS.md`
- `../PETRI_NET_FORCED_ADDTOQUEUE_TRACING.md`

La idea importante que se mantiene desde esos documentos es:

```text
Petri puede decidir cuando FreeBSD tiene libertad de politica.
Petri no debe bloquear restricciones duras del kernel.
```

Por eso `ADDTOQUEUE_FORCED` no reemplaza al modelo original. Lo completa para casos donde FreeBSD debe encolar en una CPU concreta o dentro de un conjunto restringido.
