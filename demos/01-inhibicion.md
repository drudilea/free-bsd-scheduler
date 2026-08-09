# Demo 1: inhibición de asignación de trabajo a una CPU

## Objetivo y duración

Demostrar que, al inhibir CPU1 desde el planificador Petri, una carga ordinaria que antes se distribuía entre las cuatro CPUs deja de entrar en CPU1 y continúa ejecutándose en las restantes.

- Duración objetivo: **2:30–2:45 minutos**.
- Presupuesto para las dos demos: aproximadamente **5:30–6:00 minutos**.
- Evidencia principal: eventos `sched:::on-cpu` observados con DTrace.
- No afirmar que la CPU se apaga físicamente ni que se reduce el consumo energético.

## Preparación fuera de cámara

Antes de grabar:

- Arrancar FreeBSD 13.1 con el kernel de inhibición instalado.
- Usar una VM con exactamente cuatro vCPU.
- Trabajar como `root`.
- Confirmar que existe `~/dtrace-measurements/scripts/cpu_distribution.d`.
- Confirmar que DTrace expone `sched:::on-cpu`.
- Cerrar programas innecesarios y desactivar notificaciones.
- Aumentar la fuente de ambas terminales a un tamaño legible en 1080p.
- Hacer una ejecución de ensayo completa. Si CPU1 ya da cero en la medición base, repetir antes de grabar.

No mostrar compilación, instalación ni reinicio en este video. El video comienza con el kernel correcto ya iniciado.

## Disposición de pantalla

Usar dos terminales visibles durante toda la demo:

```text
┌──────────────────────────┬──────────────────────────────────┐
│ CONTROL Y CARGA          │ DTRACE Y COMPARACIÓN             │
│ 44 % del ancho           │ 56 % del ancho                   │
│                          │                                  │
│ - Verificación de kernel │ - Distribución por CPU           │
│ - OpenSSL                │ - Resumen antes/después          │
│ - Activación del módulo  │                                  │
└──────────────────────────┴──────────────────────────────────┘
```

La terminal derecha debe ser un poco más ancha porque contiene los resultados que se compararán. Limpiar ambas terminales antes de comenzar y procurar que los prompts sean cortos.

## Guion cronometrado

### 0:00–0:20 — Presentación

**Pantalla:** ambas terminales limpias, sin ejecutar carga todavía.

**Speech:**

> En esta demostración vamos a observar el módulo de inhibición de asignación de trabajo. La funcionalidad no apaga físicamente un procesador: modifica el estado de la Red de Petri para impedir que una CPU seleccionada reciba nuevo trabajo ordinario. Primero mediremos el comportamiento normal y luego repetiremos la misma carga con CPU1 inhibida.

### 0:20–0:35 — Verificar el entorno

**Terminal izquierda:**

```sh
# Muestra la versión del sistema, la rama/commit del kernel y la arquitectura.
uname -a

# Muestra el archivo de kernel con el que arrancó actualmente FreeBSD.
sysctl kern.bootfile

# -d muestra la descripción del sysctl sin intentar cambiar su valor.
sysctl -d kern.sched_petri.cpu_toggle
```

**Resultado que debe quedar visible:** FreeBSD 13.1, el kernel de inhibición y la descripción del control `cpu_toggle`.

**Speech:**

> Estamos ejecutando FreeBSD 13.1 con el kernel de prueba del planificador Petri. El control `cpu_toggle` permite alternar el estado de las CPUs 1, 2 y 3. CPU0 se excluye por una decisión conservadora de estabilidad.

No leer `kern.sched_petri.cpu_toggle` como indicador de estado: su lectura devuelve `-1` porque el sysctl fue implementado como disparador, no como consulta persistente.

### 0:35–1:05 — Medición base

**Acción 1 — terminal derecha:** iniciar DTrace y dejarlo ejecutándose.

```sh
# timeout 24: detiene la medición después de 24 segundos.
# dtrace -s: ejecuta el script indicado por archivo.
# cpu_distribution.d: cuenta eventos sched:::on-cpu de procesos "openssl"
# y los agrupa por CPU.
# tee: muestra la salida en pantalla y simultáneamente la guarda en el archivo.
timeout 24 dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d | tee /tmp/inhibition-before.txt
```

**Acción 2 — terminal izquierda:** inmediatamente después, iniciar la carga.

```sh
# speed: ejecuta el benchmark incluido en OpenSSL.
# -seconds 20: mantiene cada prueba durante 20 segundos.
# -bytes 8192: procesa bloques de 8192 bytes.
# -multi 4: crea cuatro procesos de trabajo concurrentes.
# sha256: utiliza el cálculo de SHA-256 como carga CPU-bound.
openssl speed -seconds 20 -bytes 8192 -multi 4 sha256
```

**Speech durante la ejecución:**

> A la derecha, DTrace registra cada entrada en ejecución de procesos llamados `openssl` y agrupa los eventos por CPU. A la izquierda ejecutamos cuatro procesos de cálculo durante veinte segundos. Con el módulo inactivo esperamos observar trabajo distribuido entre las cuatro CPUs, incluida CPU1.

Cuando DTrace termine, señalar brevemente la fila `cpu,1,...`. Los números exactos pueden variar; solo importa que CPU1 tenga eventos en la medición base.

### 1:05–1:25 — Activar la inhibición

**Terminal izquierda:**

```sh
# Escribe el identificador 1 en el control del scheduler Petri.
# El sysctl funciona como toggle: si CPU1 estaba habilitada, la inhibe;
# si ya estaba inhibida, la vuelve a habilitar.
# La redirección oculta el engañoso "-1 -> -1": el control es un disparador
# y no conserva un valor legible. El efecto se comprueba después con DTrace.
sysctl kern.sched_petri.cpu_toggle=1 >/dev/null
```

**Speech:**

> Ahora inhibimos CPU1. Internamente se dispara una transición del modelo y la plaza que representa la inhibición de encolado para esa CPU, queda marcada. Esto bloquea su selección para nuevo trabajo ordinario. La CPU sigue presente y puede ejecutar su `idlethread` o hilos obligatorios del kernel.

### 1:25–1:55 — Repetir la misma medición

**Acción 1 — terminal derecha:**

```sh
# Repite exactamente la medición anterior, pero guarda la salida posterior
# a la inhibición en un archivo diferente para poder compararlas.
timeout 24 dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d | tee /tmp/inhibition-after.txt
```

**Acción 2 — terminal izquierda:**

```sh
# Se repiten sin cambios la duración, el tamaño de bloque, la concurrencia
# y el algoritmo para que la única variable controlada sea la inhibición de CPU1.
openssl speed -seconds 20 -bytes 8192 -multi 4 sha256
```

**Speech durante la ejecución:**

> Repetimos exactamente la misma carga y la misma medición. La carga continúa progresando, pero el planificador Petri ya no debería elegir CPU1. Los eventos deben concentrarse en CPU0, CPU2 y CPU3.

### 1:55–2:30 — Comparación final

**Terminal derecha:** limpiar la vista y normalizar ambos resultados para que siempre aparezcan las cuatro CPUs, incluso cuando una tenga cero eventos.

```sh
# Limpia la terminal derecha antes de presentar el resultado consolidado.
clear

# Etiqueta la primera medición.
echo "ANTES: módulo inactivo"

# -F, indica que el separador de columnas es una coma.
# /^cpu,/ conserva las filas de distribución por CPU; como el archivo contiene
# resúmenes parciales y uno final, n[$2]=$3 conserva el último valor de cada CPU.
# END imprime siempre CPU0..CPU3; n[i]+0 convierte una CPU ausente en cero.
awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/inhibition-before.txt

# Etiqueta la medición realizada después de inhibir CPU1.
echo "DESPUÉS: CPU1 inhibida"

# Aplica la misma normalización al archivo posterior a la inhibición.
awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/inhibition-after.txt

#######################
echo "ANTES: módulo inactivo"
awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/inhibition-before.txt
echo "DESPUÉS: CPU1 inhibida"
awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/inhibition-after.txt
```

**Pantalla:** mantener visible la comparación hasta terminar el cierre.

**Speech:**

> En la primera medición CPU1 recibió trabajo de OpenSSL. Después de activar la inhibición, CPU1 registra cero entradas, mientras la carga continúa ejecutándose en las demás CPUs. Este es el comportamiento que buscamos validar: la Red de Petri deja de seleccionar CPU1 para la carga observada. El resultado es una validación funcional del control de asignación; no implica apagado físico, ahorro energético ni aislamiento absoluto del procesador.
>
> [AGREGADO POR MI] Los números asociados a cada CPU indican cuántas veces los procesos de OpenSSL comenzaron o reanudaron su ejecución en una CPU.

## Después de detener la grabación

Restaurar CPU1 repitiendo el mismo toggle:

```sh
# Repite el mismo toggle para retirar la inhibición y restaurar CPU1.
# Se oculta nuevamente la salida porque no representa el estado de la CPU.
sysctl kern.sched_petri.cpu_toggle=1 >/dev/null
```

## Criterios para aceptar la toma

La toma es válida si:

- El kernel mostrado corresponde al módulo de inhibición.
- La medición base registra al menos una entrada de `openssl` en CPU1.
- La medición posterior muestra `CPU1: 0`.
- OpenSSL termina las dos ejecuciones sin error.
- No aparecen mensajes `Non sensitized`, panic o reinicio inesperado.
- El speech habla de inhibición de asignación, no de apagado de CPU.

Repetir la toma si la medición base produce casualmente `CPU1: 0`, si se activa el toggle antes de terminar la primera traza o si se pierde parte de una de las terminales en la captura.

## Notas de edición

- No acelerar los momentos en que aparecen los resultados finales.
- Los dos intervalos de veinte segundos pueden recortarse ligeramente, pero conservar al menos una actualización parcial de DTrace para que se vea que la medición ocurre en vivo.
- Puede grabarse primero la pantalla y añadir el speech después; las marcas de tiempo son una guía de montaje, no requieren locución perfectamente sincronizada.
- Evitar música o elementos gráficos que compitan con los valores de DTrace.

## Tabla rápida de comandos limpios

Ejecutar las filas de arriba hacia abajo. Cuando una fila contiene comandos en ambas columnas, iniciar primero el comando de la terminal derecha y ejecutar inmediatamente después el de la izquierda.

<table>
  <thead>
    <tr>
      <th>Terminal izquierda — control y carga</th>
      <th>Terminal derecha — DTrace y comparación</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>uname -a</td><td>—</td></tr>
    <tr><td>sysctl kern.bootfile</td><td>—</td></tr>
    <tr><td>sysctl -d kern.sched_petri.cpu_toggle</td><td>—</td></tr>
    <tr><td>openssl speed -seconds 20 -bytes 8192 -multi 4 sha256</td><td>timeout 24 dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d | tee /tmp/inhibition-before.txt</td></tr>
    <tr><td>sysctl kern.sched_petri.cpu_toggle=1 >/dev/null</td><td>—</td></tr>
    <tr><td>openssl speed -seconds 20 -bytes 8192 -multi 4 sha256</td><td>timeout 24 dtrace -s ~/dtrace-measurements/scripts/cpu_distribution.d | tee /tmp/inhibition-after.txt</td></tr>
    <tr><td>—</td><td>clear</td></tr>
    <tr><td>—</td><td>echo "ANTES: módulo inactivo"</td></tr>
    <tr><td>—</td><td>awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/inhibition-before.txt</td></tr>
    <tr><td>—</td><td>echo "DESPUÉS: CPU1 inhibida"</td></tr>
    <tr><td>—</td><td>awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/inhibition-after.txt</td></tr>
    <tr><td>sysctl kern.sched_petri.cpu_toggle=1 >/dev/null — fuera de cámara, restaura CPU1</td><td>—</td></tr>
  </tbody>
</table>
