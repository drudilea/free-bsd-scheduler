# Demo 3 — versión anterior: encolado forzado con CPU1 inhibida

> Esta variante se conserva para comparar resultados. El guion recomendado,
> basado en el escenario `cpuset -l 1,2` documentado en la tesis, está en
> `03-encolado-forzado.md` y no inhibe ninguna CPU.

## Alcance y duración

Esta es una prueba breve para mostrar cómo funciona el encolado forzado. Utilizamos el módulo de inhibición para crear deliberadamente un conflicto entre la política de la Red de Petri y una restricción de afinidad que el kernel debe respetar. No corresponde a un tercer módulo ni reproduce literalmente la medición histórica del informe.

El objetivo es mostrar cómo se resuelven las obligaciones internas del kernel cuando la política ordinaria de Petri no puede satisfacerlas. Si CPU1 está inhibida pero `cpuset` obliga a ejecutar una carga allí, el planificador:

1. respeta la restricción de afinidad;
2. despierta CPU1;
3. registra el encolado obligatorio mediante `TRAN_ADDTOQUEUE_FORCED`;
4. continúa registrando los cambios de la red sin transiciones bloqueadas durante la medición.

- Duración objetivo: **1:20–1:40 minutos**.
- Evidencia principal: probes SDT del proveedor `petri` observados con DTrace.
- No afirmar que el resultado reproduce los conteos históricos de la tesis.
- No afirmar ausencia universal de fallos: `BLOCKED_TRANSITIONS = 0` solo describe la ventana observada.

## Preparación fuera de cámara

Antes de probar o grabar:

- Arrancar FreeBSD 13.1 con el kernel construido desde `feature/petri-net-scheduler_cpu-on-off-module`, commit `90234519327d`.
- No utilizar la rama antigua `testing/petri-net-scheduler_cpu-on-off-module`: no contiene `TRAN_ADDTOQUEUE_FORCED` ni el tracer correspondiente.
- Usar una VM con exactamente cuatro vCPU y trabajar como `root`.
- Usar bash en ambas terminales.
- Actualizar `~/freebsd-wiki` y confirmar que existe `~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d`.
- Confirmar fuera de cámara que `dtrace -l -P petri` muestra los probes del proveedor `petri`.
- Reiniciar la VM antes del ensayo, o llegar desde la demo de inhibición habiendo restaurado CPU1. El primer toggle de este guion supone que CPU1 comienza activa.
- Cerrar cargas anteriores y eliminar `/tmp/forced-addtoqueue.txt` si existe.

El propio encolado forzado despierta CPU1 para respetar `cpuset`. Por eso **no debe ejecutarse otro `cpu_toggle` al terminar**: en condiciones normales CPU1 ya habrá quedado activa.

## Disposición de pantalla

Usar dos terminales durante toda la demostración:

```text
┌────────────────────────────────┬──────────────────────────────────────┐
│ CONTROL Y CARGA                │ DTRACE                               │
│ 45 % del ancho                 │ 55 % del ancho                       │
│                                │                                      │
│ - inhibir CPU1                 │ - decisiones de sched_add()          │
│ - cpuset + OpenSSL             │ - policy / forced / blocked          │
└────────────────────────────────┴──────────────────────────────────────┘
```

La terminal derecha debe ser más ancha porque el resumen de DTrace contiene varias columnas.

## Guion cronometrado

### 0:00–0:20 — Presentar el caso

**Speech:**

> En esta prueba vamos a mostrar cómo funciona el encolado forzado. Normalmente, la Red de Petri decide a qué CPU enviar cada hilo. Pero el kernel también tiene reglas que siempre debe respetar, como la afinidad, el `pinning` o el `bounding`. Vamos a crear un caso donde ambas condiciones entran en conflicto y veremos cómo se resuelve sin perder la sincronización entre el kernel y la red.

### 0:20–0:35 — Verificar el entorno

**Terminal izquierda:**

```bash
# Muestra la versión del sistema, la identificación del kernel y la arquitectura.
uname -a

# Muestra el archivo de kernel utilizado durante el arranque actual.
sysctl kern.bootfile

# -d muestra la descripción del control sin modificar su estado.
sysctl -d kern.sched_petri.cpu_toggle
```

**Resultado esperado:** FreeBSD 13.1, el kernel de inhibición y la descripción del control `cpu_toggle`.

**Speech:**

> Estamos ejecutando FreeBSD 13.1 con el kernel de prueba del planificador Petri. Vamos a utilizar `cpu_toggle` para inhibir CPU1 y DTrace para ver qué tipo de encolado realiza el kernel.

### 0:35–0:45 — Inhibir CPU1

**Terminal izquierda:**

```bash
# El valor 1 identifica CPU1.
# El sysctl funciona como toggle: partiendo de CPU1 activa, este disparo la inhibe.
# La redirección oculta el valor engañoso "-1 -> -1" del control.
sysctl kern.sched_petri.cpu_toggle=1 >/dev/null
```

**Speech:**

> Primero inhibimos CPU1 para que no reciba nuevo trabajo. No buscamos volver a demostrar la inhibición: la usamos para preparar el conflicto. En el siguiente paso obligaremos al kernel a ejecutar la carga justamente en esa CPU.

### 0:45–1:15 — Observar el encolado forzado

**Acción 1 — terminal derecha:** iniciar DTrace.

```bash
# timeout -s INT 26 envía SIGINT después de 26 segundos. DTrace procesa esa
# señal como una finalización normal e imprime sus cláusulas de resumen.
# petri_addtoqueue.d cuenta decisiones globales, normales y forzadas, además
# de clasificar el motivo y detectar intentos de transición bloqueados.
# tee muestra la traza y guarda una copia para presentar un resumen limpio.
timeout -s INT 26 dtrace -s ~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d | tee /tmp/forced-addtoqueue.txt
```

**Acción 2 — terminal izquierda:** inmediatamente después, ejecutar la carga.

```bash
# cpuset -l 1 restringe el proceso y sus hijos exclusivamente a CPU1.
# speed ejecuta el benchmark de OpenSSL.
# -seconds 20 mantiene cada prueba durante veinte segundos.
# -bytes 8192 utiliza bloques de 8192 bytes.
# -multi 4 crea cuatro procesos trabajadores.
# sha256 selecciona el cálculo CPU-bound utilizado como carga.
cpuset -l 1 openssl speed -seconds 20 -bytes 8192 -multi 4 sha256
```

**Speech durante la ejecución:**

> `cpuset` obliga a ejecutar OpenSSL únicamente en CPU1. Como esa CPU estaba inhibida, la red no podía seleccionarla normalmente, pero el kernel tampoco podía enviar la carga a otra CPU. Para resolverlo, despierta CPU1 y registra el encolado con `TRAN_ADDTOQUEUE_FORCED`. Así respeta la afinidad y la red registra lo que realmente ocurrió.

Esperar a que OpenSSL y DTrace terminen. No ejecutar otros comandos mientras las trazas están activas.

### 1:15–1:40 — Mostrar el resumen

**Terminal derecha:**

```bash
# Limpia el detalle extenso producido por DTrace.
clear

# Imprime únicamente los tres bloques de resumen y se detiene antes del
# detalle por TID, CPU y marcado. La variable show pertenece a awk.
awk '/Petri sched_add decision totals:/ {show=1} /Petri sched_add decisions by reason/ {show=0} show {print}' /tmp/forced-addtoqueue.txt
```

**Señalar en pantalla:**

- `ADDTOQUEUE_FORCED` mayor que cero.
- `affinity-fallback` mayor que cero.
- `ADDTOQUEUE_POLICY` normalmente mayor que cero después de despertar CPU1.
- `BLOCKED_TRANSITIONS` igual a cero.
- Los totales de decisiones `POLICY` y `FORCED` deben coincidir con los totales de sus respectivos disparos.

**Speech de cierre:**

> El resultado muestra encolados normales y también encolados forzados por la afinidad. Además, no se registraron transiciones bloqueadas durante la prueba. `TRAN_ADDTOQUEUE_FORCED` no evita la Red de Petri: permite que el kernel cumpla una regla obligatoria y que la red registre correctamente ese encolado.

## Después de la prueba

No repetir `kern.sched_petri.cpu_toggle=1`: OpenSSL completó su ejecución restringida a CPU1, por lo que el camino forzado ya tuvo que despertarla.

La captura puede eliminarse cuando ya no sea necesaria:

```bash
# Elimina solamente la salida temporal de esta demostración.
rm -f /tmp/forced-addtoqueue.txt
```

## Criterios para aceptar el ensayo

Aceptar la ejecución si:

- OpenSSL completa normalmente bajo `cpuset -l 1`.
- `ADDTOQUEUE_FORCED` es mayor que cero tanto en decisiones como en disparos.
- El desglose muestra `affinity-fallback` mayor que cero.
- `BLOCKED_TRANSITIONS` es cero.
- No aparecen mensajes `Non sensitized`, panic ni reinicio inesperado.

Repetir desde un reinicio si el primer toggle pudo haber activado CPU1 en vez de inhibirla. Si `ADDTOQUEUE_FORCED` queda en cero, confirmar primero la rama y el commit; no aumentar la carga antes de verificar el kernel.

## Límites para el speech

- Es una prueba nueva para observar el encolado forzado, no el comando histórico exacto del capítulo 4.
- El tracer observa todas las decisiones de `sched_add()` durante la ventana, no únicamente OpenSSL.
- Un resultado sin bloqueos durante esta toma no demuestra ausencia universal de fallos.
- No demuestra mejoras de rendimiento ni ahorro energético.

## Tabla rápida de comandos limpios

Ejecutar las filas de arriba hacia abajo. Cuando una fila contiene comandos en ambas columnas, iniciar primero el comando de la terminal derecha y ejecutar inmediatamente después el de la izquierda.

<table>
  <thead>
    <tr>
      <th>Terminal izquierda — control y carga</th>
      <th>Terminal derecha — DTrace</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>uname -a</td><td>—</td></tr>
    <tr><td>sysctl kern.bootfile</td><td>—</td></tr>
    <tr><td>sysctl -d kern.sched_petri.cpu_toggle</td><td>—</td></tr>
    <tr><td>sysctl kern.sched_petri.cpu_toggle=1 >/dev/null</td><td>—</td></tr>
    <tr><td>cpuset -l 1 openssl speed -seconds 20 -bytes 8192 -multi 4 sha256</td><td>timeout -s INT 26 dtrace -s ~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d | tee /tmp/forced-addtoqueue.txt</td></tr>
    <tr><td>—</td><td>clear</td></tr>
    <tr><td>—</td><td>awk '/Petri sched_add decision totals:/ {show=1} /Petri sched_add decisions by reason/ {show=0} show {print}' /tmp/forced-addtoqueue.txt</td></tr>
    <tr><td>—</td><td>rm -f /tmp/forced-addtoqueue.txt — después de la prueba</td></tr>
  </tbody>
</table>
