# Cambios reales entre Petri sobre 13.1 y Petri sobre main

## Resumen

Fuera del caso `sched_throw()`, el port a `main` no requirió un rediseño de la lógica Petri.

La mayoría de los cambios son de integración:

- insertar los hooks Petri en el `sched_4bsd.c` actual;
- no arrastrar un `PI_KERNELCONF` viejo;
- no compilar Petri en kernels que no usan 4BSD;
- limpiar detalles de C que podían dificultar revisión o build.

## Tabla de cambios

| Área | Cambio respecto de 13.1 | Tipo | Motivo |
| --- | --- | --- | --- |
| `sched_throw()` | Se adaptó a la separación `sched_throw()` / `sched_ap_entry()` / `sched_throw_tail()` | Funcional por API nueva | FreeBSD `main` ya no usa `sched_throw(NULL)` |
| `sched_add()` | Misma lógica general de Petri + `ADDTOQUEUE_FORCED` | Misma lógica | Mantener sincronizada la red sin romper `pinned`, `bound` ni afinidad |
| `sched_switch()` | Mismos eventos Petri: expulsión del saliente y ejecución del entrante | Misma lógica | Reflejar `RUNNING -> ...` y `... -> RUNNING` en la red |
| `sched_choose()` | Mismo registro de cola per-CPU, cola global e `idlethread` | Misma lógica | Mantener coherencia del marcado cuando se elige un hilo |
| `sched_rem()` | Mismo registro al remover de cola per-CPU o global | Misma lógica | Evitar que Petri conserve hilos que FreeBSD ya removió |
| `PI_KERNELCONF` | Rehecho desde el `GENERIC` actual de `main` | Integración | Evitar arrastrar diferencias viejas de 13.1 |
| `sys/conf/files` | Archivos Petri como `optional sched_4bsd` | Integración | Evitar meter Petri en kernels ULE o no 4BSD |
| `kern_thread.c` | Inicialización Petri bajo `#ifdef SCHED_4BSD` | Integración | Evitar dependencia Petri fuera de 4BSD |
| estilo C | Limpieza de formato, helpers muertos y variables no usadas | Mantenimiento | Reducir riesgo de build/review |

## sched_add

La lógica importante en `sched_add()` es la misma que ya se venía usando.

La regla conceptual es:

```text
Hilo normal:
  va a cola global.

Hilo pinned:
  debe ir a su CPU.

Hilo bound:
  debe ir a la CPU asociada por FreeBSD.

Hilo con afinidad/cpuset:
  debe ir a una CPU permitida.
```

Petri participa cuando hay libertad de política. No debe anular restricciones que FreeBSD considera obligatorias.

```mermaid
flowchart TD
    A["sched_add(td)"] --> B{"td pinned, bound o affinity?"}

    B -- "no" --> C["cola global"]
    C --> D["Petri: TRAN_QUEUE_GLOBAL"]

    B -- "si" --> E{"FreeBSD impone CPU concreta?"}
    E -- "pinned / bound" --> F["usar CPU obligatoria"]
    F --> G["Petri: TRAN_ADDTOQUEUE_FORCED"]

    E -- "affinity/cpuset" --> H["Petri intenta elegir CPU válida"]
    H --> I{"ADDTOQUEUE sensibilizada?"}
    I -- "si" --> J["Petri: TRAN_ADDTOQUEUE"]
    I -- "no" --> K["FreeBSD fallback a CPU permitida"]
    K --> L["Petri: TRAN_ADDTOQUEUE_FORCED"]
```

### Por qué existe ADDTOQUEUE_FORCED

`ADDTOQUEUE_FORCED` no es una forma de ignorar Petri. Es una forma de registrar en Petri un evento que FreeBSD debe realizar.

Sin esa transición, podía pasar esto:

```text
FreeBSD:
  debe encolar un hilo en runq_pcpu[1]

Petri:
  ADDTOQUEUE_P1 está inhibida por CANTQ_P1

Resultado:
  FreeBSD encola realmente el hilo
  Petri no registra el evento
  la red queda desincronizada
```

Con `ADDTOQUEUE_FORCED`:

```text
FreeBSD:
  encola el hilo donde debe

Petri:
  registra el encolado forced
  incrementa QUEUE
  incrementa CANTQ
```

Esto mantiene la penalización de balanceo, pero evita que la red bloquee una restricción dura del kernel.

## sched_switch

La idea se mantiene:

```text
hilo saliente deja CPU -> resource_expulse_thread()
hilo entrante ejecuta  -> resource_execute_thread()
```

La diferencia con `main` no fue conceptual. El código alrededor de `sched_switch()` está más actualizado que en 13.1, por lo que los hooks se ubicaron donde el estado del hilo ya es coherente para actualizar Petri.

Flujo simplificado:

```mermaid
sequenceDiagram
    participant A as Hilo saliente
    participant S as sched_switch
    participant P as Petri
    participant B as Hilo entrante

    A->>S: entra al scheduler
    S->>P: resource_expulse_thread(A, flags)
    S->>S: si A sigue runnable, sched_add(A)
    S->>S: newtd = choosethread()
    S->>P: resource_execute_thread(B, cpu)
    S->>B: cambio de contexto
```

## sched_choose

El trabajo de `sched_choose()` es elegir qué hilo ejecutar.

En Petri importa de dónde salió ese hilo:

```text
cola per-CPU:
  TRAN_UNQUEUE_Pn

cola global:
  TRAN_FROM_GLOBAL_CPU_Pn

sin hilos disponibles:
  idlethread
```

El `idlethread` es especial porque no representa trabajo real de usuario. Aun así, Petri necesita registrar un pasaje coherente para que el marcado del hilo y de los recursos no quede roto.

## sched_rem

`sched_rem()` remueve un hilo de una cola.

Si FreeBSD remueve el hilo y Petri no lo registra, la red cree que el hilo sigue en cola. Por eso se conserva:

```text
cola per-CPU:
  resource_remove_thread(td, cpu)

cola global:
  TRAN_REMOVE_GLOBAL_QUEUE
```

## PI_KERNELCONF

En vez de traer el archivo viejo de 13.1, se tomó el `GENERIC` actual de `main` y se aplicaron solo las diferencias necesarias:

```text
ident PI_KERNELCONF
SCHED_4BSD habilitado
SCHED_ULE deshabilitado
DIAGNOSTIC habilitado
KDB_UNATTENDED habilitado
```

Esto evita que el PR muestre cientos de cambios irrelevantes por diferencias entre un `GENERIC` viejo y uno actual.

## sys/conf/files y kern_thread.c

El primer delta traía los archivos Petri como `standard`. Eso significa:

```text
compilar Petri en cualquier kernel
```

Para un PR contra `main`, eso no era conveniente. La integración quedó así:

```text
kern/petri_global_net.c  optional sched_4bsd
kern/sched_petri.c       optional sched_4bsd
```

Y en `kern_thread.c`:

```c
#ifdef SCHED_4BSD
init_petri_thread(td);
#endif
```

Con esto, Petri queda atado al planificador 4BSD, que es donde realmente se integra.

## Qué no se cambió

No se cambió la idea central del modelo:

```text
ADDTOQUEUE
UNQUEUE
EXEC
RETURN_VOL
RETURN_INVOL
FROM_GLOBAL_CPU
REMOVE_QUEUE
REMOVE_GLOBAL_QUEUE
ADDTOQUEUE_FORCED
```

Tampoco se agregaron los módulos:

```text
CPU on/off
CPU monopolize
```

Esos deberían llegar después, en PRs separados.
