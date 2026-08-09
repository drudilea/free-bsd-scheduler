# Demo 3: encolado forzado con afinidad restringida

## Alcance y duración

Esta prueba intenta reproducir el escenario documentado en la tesis como `cpuset -l 1,2`. Las cuatro CPUs permanecen activas: no se utiliza `cpu_toggle` ni se inhibe ningún procesador.

`cpuset` limita la carga a CPU1 y CPU2. Mientras alguna de esas CPUs está disponible para el camino normal de la Red de Petri, el kernel utiliza `TRAN_ADDTOQUEUE`. Si ninguna de las CPUs permitidas puede recibir el hilo por ese camino, el kernel debe respetar igualmente la afinidad y registra el encolado mediante `TRAN_ADDTOQUEUE_FORCED`.

- Duración objetivo: **1:20–1:40 minutos**.
- Evidencia principal: probes SDT del proveedor `petri` observados con DTrace.
- Se reproduce la configuración de afinidad documentada, pero no se conocen el ejecutable ni los parámetros históricos exactos.
- No se esperan los mismos conteos o porcentajes de la tesis: dependen de la carga y de la actividad del sistema durante la ventana observada.
- `BLOCKED_TRANSITIONS = 0` describe únicamente esta ejecución.

## Preparación fuera de cámara

Antes de probar o grabar:

- Arrancar FreeBSD 13.1 con un kernel construido desde `testing/petri-forced-addtoqueue`, commit `410b708cc382`.
- No utilizar para esta reproducción el kernel de inhibición del commit `90234519327d`: contiene la corrección forzada, pero su matriz de inhibición no reproduce exactamente el papel de `PLACE_CANTQ` evaluado en la prueba histórica.
- Reiniciar la VM con las cuatro CPUs activas. Esta rama no contiene el control `kern.sched_petri.cpu_toggle` ni el módulo de inhibición de CPUs.
- Usar una VM con exactamente cuatro vCPU y trabajar como `root`.
- Usar bash en ambas terminales.
- Actualizar `~/freebsd-wiki` y confirmar que existe `~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d`.
- Confirmar fuera de cámara que `dtrace -l -P petri` muestra los probes del proveedor `petri`.
- Cerrar cargas anteriores.

Comprobaciones recomendadas fuera de cámara:

```bash
# Actualiza el repositorio que contiene el tracer utilizado por la demo.
cd ~/freebsd-wiki
git pull --ff-only origin master

# -f comprueba que la ruta corresponde a un archivo regular.
test -f ~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d; and echo "Tracer disponible"

# Confirma que el kernel expone los probes SDT personalizados del proveedor petri.
dtrace -l -P petri
```

## Disposición de pantalla

Usar dos terminales durante toda la demostración:

```text
┌────────────────────────────────┬──────────────────────────────────────┐
│ ENTORNO Y CARGA                │ DTRACE                               │
│ 45 % del ancho                 │ 55 % del ancho                       │
│                                │                                      │
│ - verificar el kernel          │ - decisiones de sched_add()          │
│ - cpuset + OpenSSL             │ - policy / forced / blocked          │
└────────────────────────────────┴──────────────────────────────────────┘
```

La terminal derecha debe ser más ancha porque el resumen de DTrace contiene varias columnas.

## Guion cronometrado

### 0:00–0:20 — Presentar el caso

**Speech:**

> En esta prueba vamos a reproducir el escenario de afinidad restringida que aparece en la tesis. No vamos a inhibir ninguna CPU. Vamos a limitar una carga a CPU1 y CPU2 para observar cuándo la Red de Petri puede encolarla normalmente y cuándo el kernel necesita utilizar el encolado forzado para respetar esa restricción.

### 0:20–0:35 — Verificar el entorno

**Terminal izquierda:**

```bash
# Muestra la versión del sistema, la identificación del kernel y la arquitectura.
uname -a

# Muestra el archivo de kernel utilizado durante el arranque actual.
sysctl kern.bootfile
```

**Resultado esperado:** FreeBSD 13.1 y el kernel construido desde `testing/petri-forced-addtoqueue`.

**Speech:**

> Estamos ejecutando FreeBSD 13.1 con el kernel utilizado para validar la corrección del encolado forzado. Las cuatro CPUs están activas y esta versión no incluye el módulo de inhibición. DTrace nos permitirá distinguir los encolados globales, los encolados normales y los encolados forzados.

### 0:35–1:10 — Ejecutar el escenario `cpuset -l 1,2`

**Acción 1 — terminal derecha:** eliminar una captura anterior e iniciar DTrace.

```bash
# Elimina únicamente una salida anterior para evitar mostrar datos viejos si
# la nueva medición se interrumpe antes de escribir el archivo.
rm -f /tmp/forced-addtoqueue-cpuset.txt

# timeout -s INT 26 envía SIGINT después de 26 segundos. DTrace interpreta
# esa señal como una finalización normal e imprime sus resúmenes acumulados.
# petri_addtoqueue.d cuenta decisiones globales, normales y forzadas, clasifica
# el motivo del camino forzado y detecta transiciones no sensibilizadas.
# tee muestra la traza y guarda una copia para el resumen final.
timeout -s INT 26 dtrace -s ~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d | tee /tmp/forced-addtoqueue-cpuset.txt
```

**Acción 2 — terminal izquierda:** inmediatamente después, ejecutar la carga.

```bash
# cpuset -l 1,2 restringe el proceso y sus hijos a CPU1 y CPU2. No apaga ni
# inhibe esas CPUs y tampoco permite que esta carga se ejecute en CPU0 o CPU3.
# speed ejecuta el benchmark de OpenSSL.
# -seconds 20 mantiene la prueba durante veinte segundos.
# -bytes 8192 utiliza bloques de 8192 bytes.
# -multi 4 crea cuatro procesos trabajadores.
# sha256 selecciona el cálculo CPU-bound utilizado como carga.
cpuset -l 1,2 openssl speed -seconds 20 -bytes 8192 -multi 4 sha256
```

**Speech durante la ejecución:**

> `cpuset` permite que esta carga se ejecute solamente en CPU1 y CPU2. Cuando alguna de esas CPUs está disponible para el camino normal, la Red de Petri decide el encolado. Si las dos están temporalmente penalizadas por el marcado de la red, el kernel no puede enviar la carga a CPU0 o CPU3 porque violaría la afinidad. En ese caso utiliza `TRAN_ADDTOQUEUE_FORCED` para registrar correctamente el encolado obligatorio.

Esperar a que OpenSSL y DTrace terminen. No ejecutar otros comandos mientras la traza está activa.

### 1:10–1:40 — Mostrar el resumen

**Terminal derecha:**

```bash
# Limpia el detalle extenso producido por DTrace.
clear

# Imprime los tres bloques de resumen y se detiene antes del detalle agrupado
# por motivo, CPU y transición. La variable show pertenece a awk.
awk '/Petri sched_add decision totals:/ {show=1} /Petri sched_add decisions by reason/ {show=0} show {print}' /tmp/forced-addtoqueue-cpuset.txt
```

**Señalar en pantalla:**

- `ADDTOQUEUE_POLICY` mayor que cero.
- `ADDTOQUEUE_FORCED` mayor que cero.
- `affinity-fallback` mayor que cero dentro del desglose forzado.
- Las decisiones `POLICY` y `FORCED` coinciden con sus transiciones disparadas.
- `BLOCKED_TRANSITIONS` igual a cero.

No comparar los conteos absolutos con `311` y `198` durante el video. Lo importante es que aparezcan ambos caminos y que la red registre las decisiones sin transiciones bloqueadas.

**Speech de cierre:**

> El resultado muestra los dos caminos descriptos en la tesis. La Red de Petri sigue decidiendo cuando encuentra una CPU permitida y disponible. Cuando la afinidad debe respetarse y el camino normal no alcanza, aparece el encolado forzado. Las decisiones coinciden con las transiciones registradas y no observamos transiciones bloqueadas durante esta prueba.

## Después de la prueba

No es necesario restaurar el estado de ninguna CPU porque la demostración no utilizó `cpu_toggle`.

La captura puede eliminarse cuando ya no sea necesaria:

```bash
# Elimina solamente la salida temporal de esta demostración.
rm -f /tmp/forced-addtoqueue-cpuset.txt
```

## Criterios para aceptar el ensayo

Aceptar la ejecución si:

- OpenSSL completa normalmente bajo `cpuset -l 1,2`.
- `ADDTOQUEUE_POLICY` es mayor que cero en decisiones y disparos.
- `ADDTOQUEUE_FORCED` es mayor que cero en decisiones y disparos.
- El desglose muestra `affinity-fallback` mayor que cero.
- Los totales de decisiones por CPU coinciden con los totales de transiciones disparadas.
- `BLOCKED_TRANSITIONS` es cero.
- No aparecen mensajes `Non sensitized`, panic ni reinicio inesperado.

Si el primer ensayo no muestra ambos caminos, conservar la salida y comprobar primero que el kernel corresponde al commit `410b708cc382`. Después, repetir una sola vez desde un reinicio antes de modificar la carga.

## Límites para el speech

- Se reproduce `cpuset -l 1,2`, pero el comando histórico completo no quedó archivado.
- OpenSSL es una carga reproducible elegida a partir de las demás mediciones del proyecto.
- El tracer observa todas las decisiones de `sched_add()` durante la ventana, no únicamente OpenSSL.
- Un resultado sin bloqueos durante esta toma no demuestra ausencia universal de fallos.
- No demuestra mejoras de rendimiento ni ahorro energético.

## Tabla rápida de comandos limpios

Ejecutar las filas de arriba hacia abajo. En la fila con comandos en ambas columnas, iniciar primero DTrace en la terminal derecha y ejecutar inmediatamente después OpenSSL en la terminal izquierda.

<table>
  <thead>
    <tr>
      <th>Terminal izquierda — entorno y carga</th>
      <th>Terminal derecha — DTrace</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>uname -a</td><td>—</td></tr>
    <tr><td>sysctl kern.bootfile</td><td>—</td></tr>
    <tr><td>—</td><td>rm -f /tmp/forced-addtoqueue-cpuset.txt</td></tr>
    <tr><td>cpuset -l 1,2 openssl speed -seconds 20 -bytes 8192 -multi 4 sha256</td><td>timeout -s INT 26 dtrace -s ~/freebsd-wiki/utils/scripts/DTrace/petri_addtoqueue.d | tee /tmp/forced-addtoqueue-cpuset.txt</td></tr>
    <tr><td>—</td><td>clear</td></tr>
    <tr><td>—</td><td>awk '/Petri sched_add decision totals:/ {show=1} /Petri sched_add decisions by reason/ {show=0} show {print}' /tmp/forced-addtoqueue-cpuset.txt</td></tr>
    <tr><td>—</td><td>rm -f /tmp/forced-addtoqueue-cpuset.txt — después de la prueba</td></tr>
  </tbody>
</table>
