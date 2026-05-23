# Contexto del port a main

## Problema inicial

La rama base del planificador Petri estaba basada en FreeBSD 13.1. La pregunta del experimento fue:

```text
¿Qué tan lejos está el trabajo Petri de FreeBSD main?
```

Una primera estrategia posible era hacer un merge directo:

```text
origin/main + feature/petri-net-scheduler
```

Ese merge completo produjo una cantidad enorme de conflictos. Ese resultado no era una buena medida técnica del problema real, porque mezclaba dos cosas:

1. diferencias propias de FreeBSD entre 13.1 y `main`;
2. cambios reales del proyecto Petri.

En otras palabras, el merge completo arrastraba diferencias históricas de FreeBSD y convertía el análisis en ruido.

## Estrategia usada

La estrategia más útil fue aplicar solamente el delta del proyecto:

```text
git diff origin/release13.1...feature/petri-net-scheduler
```

Ese delta representa:

```text
FreeBSD 13.1 limpio
        +
cambios de la rama base Petri
```

Aplicar ese patch sobre `origin/main` responde una pregunta más precisa:

```text
Si se toma solo el trabajo Petri, ¿qué hay que adaptar para que entre en main?
```

Con ese enfoque, los conflictos se redujeron a:

```text
.gitignore
sys/kern/sched_4bsd.c
```

El conflicto de `.gitignore` fue trivial. El conflicto real estuvo en `sched_4bsd.c`.

## Mapa general

```mermaid
flowchart TD
    A["FreeBSD 13.1"] --> B["feature/petri-net-scheduler"]
    C["FreeBSD main"] --> D["feature/petri-net-scheduler-main-port"]
    B -->|"delta Petri, no merge completo"| D

    E["merge completo"] --> F["muchos conflictos históricos"]
    G["delta del proyecto"] --> H["conflictos reales pequeños"]

    F -. "ruido" .-> X["no usar como señal principal"]
    H --> Y["resolver sched_4bsd.c"]
```

## Qué se considera dentro del alcance

Este port incluye la base del planificador Petri:

- red del hilo;
- red global de recursos CPU;
- integración con `sched_4bsd.c`;
- `ADDTOQUEUE_FORCED`;
- trazabilidad DTrace de decisiones `sched_add`;
- `PI_KERNELCONF`.

Este port no incluye:

- módulo de encendido/apagado de CPUs;
- módulo de monopolización;
- PRs encadenados sobre esos módulos.

## Por qué importa separar base y módulos

La base Petri debe quedar como plataforma común. Si se mezclan los módulos en el mismo PR, se vuelve difícil responder:

```text
¿El problema está en el scheduler Petri base?
¿El problema está en on/off?
¿El problema está en monopolización?
¿El problema es un conflicto con main?
```

Separar los PRs permite validar primero que el scheduler base puede funcionar sobre `main`. Después, los módulos pueden actualizarse sobre esa base sin duplicar arreglos.

## Resultado del experimento

El resultado preliminar es positivo:

```text
El port base a main es viable.
```

La razón es que no apareció una incompatibilidad conceptual importante entre Petri y `main`. El cambio relevante de FreeBSD fue principalmente estructural: la separación de `sched_throw()` y `sched_ap_entry()`.

El resto de la lógica Petri se pudo mantener casi igual a la rama 13.1, con ajustes de integración para que el PR sea revisable.
