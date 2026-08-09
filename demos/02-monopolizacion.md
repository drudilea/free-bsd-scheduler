# Demo 2: monopolización de una CPU por un hilo

## Objetivo y duración

Demostrar que, al reservar CPU2 para un TID específico desde el planificador Petri:

1. El TID deja de migrar entre CPUs y pasa a ejecutar únicamente en CPU2.
2. CPU2 deja de recibir otros hilos ordinarios de usuario durante la medición.

- Duración objetivo: **2:50–3:15 minutos**.
- Duración estimada de ambas demos: aproximadamente **5:30–6:00 minutos**.
- Evidencia principal: eventos `sched:::on-cpu` observados con DTrace.
- No afirmar aislamiento absoluto: la medición excluye `idle`, actividad con `pid == 0`, interrupciones y otros caminos internos del kernel.

## Preparación fuera de cámara

Antes de grabar:

- Arrancar FreeBSD 13.1 con el kernel de monopolización construido desde `testing/petri-net-scheduler_monopolize-cpu-module`, commit `5ed1d1703e89`.
- Usar una VM con exactamente cuatro vCPU.
- Trabajar como `root`.
- Confirmar que `kern.sched_petri.monopolize_state` muestra todas las CPUs libres.
- Confirmar que existen `thread_cpu_distribution.d` y `reserved_cpu_foreign_threads.d` dentro de `~/dtrace-measurements/scripts/`.
- Compilar `project_files/test_files/single_thread_multiplier` con `make CC=cc`.
- Ejecutar una prueba completa y cerrar correctamente la carga antes de grabar.
- Cerrar programas innecesarios y desactivar notificaciones.
- Usar una fuente grande y prompts cortos.
- Mantener bash como shell en las dos terminales derechas; los comandos del
  guion utilizan su sintaxis de variables.

No mostrar compilación, instalación ni reinicio. El video comienza con el kernel correcto ya iniciado.

Los comandos obtienen automáticamente el TID de la fila `run` y lo guardan en `$WORKER_TID`. No utilizar el TID de la fila `ttyin`.

## Disposición de pantalla

Usar tres terminales, con la carga ocupando toda la altura a la izquierda:

```text
┌──────────────────────────┬──────────────────────────────────┐
│ CARGA CPU-BOUND          │ CONTROL Y DISTRIBUCIÓN DEL TID   │
│ 40 % del ancho           │ 60 % del ancho / mitad superior │
│                          ├──────────────────────────────────┤
│ single_thread_multiplier │ EXCLUSIÓN DE OTROS HILOS         │
│ permanece ejecutándose   │ 60 % del ancho / mitad inferior │
└──────────────────────────┴──────────────────────────────────┘
```

- **Izquierda:** mantiene vivo `single_thread_multiplier`; no se escriben más comandos allí hasta terminar.
- **Derecha superior:** verifica el kernel, obtiene el TID, controla la reserva y mide la distribución del hilo.
- **Derecha inferior:** genera carga concurrente y busca otros hilos en CPU2.

La terminal superior derecha es la protagonista. La inferior puede usar una fuente apenas menor, pero su resultado final debe ser legible.

## Guion cronometrado

### 0:00–0:20 — Presentación

**Pantalla:** las tres terminales limpias.

**Speech:**

> En esta segunda demostración vamos a observar el módulo de monopolización. El objetivo es reservar una CPU para un hilo concreto. Primero veremos que el hilo puede migrar entre procesadores. Luego reservaremos CPU2 para ese TID y comprobaremos dos condiciones: que el hilo ejecuta solamente allí y que CPU2 no recibe otros hilos ordinarios durante la medición.

### 0:20–0:40 — Verificar el kernel y el estado inicial

**Terminal derecha superior:**

```bash
# Muestra la versión, rama/commit del kernel y arquitectura del sistema.
uname -a

# Muestra el archivo de kernel utilizado durante el arranque actual.
sysctl kern.bootfile

# -d muestra la descripción del control sin modificarlo.
sysctl -d kern.sched_petri.monopolize

# Muestra el TID reservado en cada CPU. El valor -1 significa CPU libre.
sysctl kern.sched_petri.monopolize_state
```

**Resultado esperado:** `cpu0:-1 cpu1:-1 cpu2:-1 cpu3:-1`.

**Speech:**

> Estamos ejecutando FreeBSD 13.1 con el kernel de monopolización. El comando ejecutado en la terminal derecha muestra las cuatro CPUs libres, por eso vemos `-1` en cada una. Este valor será reemplazado por el id del hilo que se quiera reservar para cada CPU.

### 0:40–1:00 — Iniciar la carga e identificar el hilo trabajador

**Terminal izquierda:**

```bash
# Entra en el directorio del programa de prueba ya compilado.
cd ~/freebsd-wiki/project_files/test_files/single_thread_multiplier

# Inicia un programa con un hilo principal bloqueado esperando entrada y
# un segundo hilo que ejecuta cálculos continuamente para consumir CPU.
./single_thread_multiplier
```

La terminal izquierda quedará mostrando `Press any key to exit...`. No escribir nada todavía.

**Terminal derecha superior:**

```bash
# -a incluye todos los procesos y -t muestra información de sus hilos.
# grep limita la salida al nombre truncado del programa de prueba.
procstat -at | grep single_thread_multi

# Busca la fila "run", extrae su segunda columna —el TID— y guarda el primer
# resultado en una variable de bash reutilizable por los siguientes comandos.
set WORKER_TID (procstat -at | awk '$3 == "single_thread_multi" && $7 == "run" {print $2; exit}')

# Muestra el valor capturado para comprobarlo visualmente contra procstat.
echo "WORKER_TID=$WORKER_TID"
```

**Acción visual:** señalar las dos filas. Copiar el TID de la fila cuyo estado sea `run`; la fila `ttyin` corresponde al hilo principal bloqueado y no sirve para la prueba.

**Speech:**

> En la terminal izquierda corremos un programa que ejecuta un hilo principal esperando entrada y a su vez otro hilo que hace cálculos continuamente. En la terminal de la derecha podemos ver ambos.
> Para la monopolización elegimos el ID del hilo en ejecución (en la lista aparece en estado `run`), porque ese es el hilo que realiza los cálculos. Guardamos su ID en una variable para utilizarlo en los siguientes comandos.

Antes de continuar, comprobar que `$WORKER_TID` coincide con la segunda columna de la fila `run`.

### 1:00–1:30 — Medición sin monopolización

**Terminal derecha superior:**

```bash
# timeout 24 detiene DTrace después de 24 segundos.
# dtrace -s ejecuta el script indicado por archivo.
# $WORKER_TID es el argumento $1 que filtra los eventos on-cpu del trabajador.
# tee muestra la medición y también conserva su salida para la comparación.
timeout 24 dtrace -s ~/dtrace-measurements/scripts/thread_cpu_distribution.d $WORKER_TID | tee /tmp/monopolization-before.txt
```

**Speech durante la medición:**

> Luego ejecutamos DTrace, que registra cada vez que ese hilo entra en ejecución en alguna CPU.
> El comando grupa los eventos por CPU. Como todavía no existe una monopolización, el planificador puede mover el hilo entre distintos procesadores, y es lo que vemos en los resultados parciales que se muestran.

Al finalizar, señalar brevemente que aparecen varias CPUs. Si solo aparece una, repetir esta medición antes de continuar para obtener una referencia visual clara.

### 1:30–1:50 — Reservar CPU2

**Terminal derecha superior:**

```bash
# El valor tiene formato tid:cpu. Registra CPU2 como reservada para el TID real.
# Repetir posteriormente el mismo par libera la reserva.
sysctl kern.sched_petri.monopolize=$WORKER_TID:2

# Confirma que CPU2 contiene ahora el TID seleccionado y las demás siguen libres.
sysctl kern.sched_petri.monopolize_state
```

**Resultado esperado:** CPU2 debe mostrar el valor de `$WORKER_TID` y las otras CPUs deben continuar en `-1`.

**Speech:**

> Ahora decidimos reservar la CPU2 para el hilo seleccionado utilizando el comando disponible. Luego utilizamos el mismo comando del inicio para verificar que la CPU2 muestra el ID del hilo y las demás CPUs continúan libres.

### 1:50–2:25 — Validar residencia y exclusión simultáneamente

**Acción 1 — terminal derecha superior:** iniciar la distribución del TID reservado.

```bash
# Repite la misma medición del trabajador con la reserva ya activa.
timeout 24 dtrace -s ~/dtrace-measurements/scripts/thread_cpu_distribution.d $WORKER_TID | tee /tmp/monopolization-after.txt
```

Mientras la terminal superior mide, pasar inmediatamente a la terminal inferior.

**Acción 2 — terminal derecha inferior:** iniciar una carga competidora en segundo plano.

```bash
# Obtiene en esta segunda terminal bash el mismo TID trabajador de la fila "run".
set WORKER_TID (procstat -at | awk '$3 == "single_thread_multi" && $7 == "run" {print $2; exit}')

# Confirma que el panel inferior utilizará el mismo TID que el superior.
echo "WORKER_TID=$WORKER_TID"

# speed ejecuta el benchmark de OpenSSL.
# -seconds 20 mantiene la carga durante veinte segundos.
# -bytes 8192 utiliza bloques de 8192 bytes.
# sha256 genera una carga CPU-bound acotada.
# &> guarda conjuntamente la salida estándar y los mensajes de error en bash.
# El ampersand final deja OpenSSL ejecutándose en segundo plano.
openssl speed -seconds 20 -bytes 8192 sha256 &> /tmp/monopolization-competing-openssl.txt &
```

**Acción 3 — terminal derecha inferior:** inmediatamente después, buscar intrusiones en CPU2.

```bash
# El primer argumento, 2, es la CPU reservada.
# El segundo argumento es el TID propietario que debe excluirse del conteo.
# El script registra otros hilos con pid > 0 y diferentes de idle que entren en CPU2.
# tee conserva la salida para convertir una ausencia de filas en un cero explícito.
timeout 24 dtrace -s ~/dtrace-measurements/scripts/reserved_cpu_foreign_threads.d 2 $WORKER_TID | tee /tmp/monopolization-foreign.txt
```

**Speech durante ambas mediciones:**

> Ejecutamos dos observaciones en paralelo.
> En la terminal superior derecha repetimos el mismo comando de DTrace que usamos antes para medir la distribución del hilo, pero ahora con la reserva activa.
> En la terminal inferior derecha creamos hilos adicionales con OpenSSL y ejecutamos un comando de DTrace que muestra otros hilos en CPU2 distintos al seleccionado previamente. La monopolización será válida si el primer comando muestra eventos únicamente en CPU2 y el segundo comando no muestra ningún otro hilo entrando en esa CPU.
> Es posible ver que en la terminal inferior derecha no aparecen eventos, solo las líneas de encabezado. Esto indica que no se registraron otros hilos entrando en CPU2 durante la medición.

### 2:25–2:55 — Comparación final

**Terminal derecha superior:** limpiar y normalizar la distribución antes/después.

```bash
# Limpia el panel principal antes de mostrar el resultado consolidado.
clear

# Etiqueta y normaliza la medición sin reserva.
# -F, usa la coma como separador; el último valor de cada CPU corresponde al
# resumen final. El bucle imprime CPU0..CPU3 y convierte ausencias en cero.
echo "ANTES: sin monopolización"
awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/monopolization-before.txt

# Etiqueta y normaliza la medición con el TID reservado en CPU2.
echo "DESPUÉS: TID reservado en CPU2"
awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/monopolization-after.txt
```

**Terminal derecha inferior:** convertir la ausencia de eventos extranjeros en un cero explícito.

```bash
# Si el tracer emitió filas total, conserva la última; si no emitió ninguna,
# total+0 produce cero. Esto evita interpretar visualmente un resumen vacío.
awk -F, '/^total,/ {total=$2} END {printf "Other user-thread entries on CPU2: %d\n",total+0}' /tmp/monopolization-foreign.txt
```

**Pantalla:** mantener visibles ambos resultados hasta terminar el cierre.

**Speech:**

> Antes de activar el módulo, el TID fue observado en distintos procesadores. Con la monopolización activa, todas las entradas aparecen en CPU2 y las demás CPUs quedan en cero. Al mismo tiempo, con carga concurrente, no se registraron otros hilos ordinarios entrando en CPU2. Esto valida la monopolización del hilo y la exclusión de otros durante el intervalo observado.

### 2:55–3:05 — Cierre visual

**Terminal derecha superior:** volver a mostrar el estado de la reserva.

```bash
# Confirma que la relación TID:CPU continúa activa al terminar las mediciones.
sysctl kern.sched_petri.monopolize_state
```

**Speech:**

> Para finalizar, liberamos la CPU2 y lo verificamos con el comando correspondiente.

## Después de detener la grabación

**Terminal derecha superior:** liberar CPU2 repitiendo exactamente el mismo par.

```bash
# El control es un toggle: repetir el par TID:CPU elimina la reserva.
sysctl kern.sched_petri.monopolize=$WORKER_TID:2

# Verifica que CPU2 haya vuelto al valor -1.
sysctl kern.sched_petri.monopolize_state
```

**Terminal izquierda:** escribir `0` y presionar Enter para finalizar el programa. Aunque el mensaje dice `Press any key`, el código usa `scanf("%d")` y espera un número entero.

## Criterios para aceptar la toma

La toma es válida si:

- El kernel mostrado corresponde al commit `5ed1d1703e89` de la rama de testing.
- Se utiliza el TID de la fila `run`, no el TID principal en `ttyin`.
- Antes de la reserva se observan eventos del TID en más de una CPU.
- Después de la reserva, la comparación muestra eventos únicamente en CPU2.
- `monopolize_state` muestra el TID correcto en CPU2.
- La verificación inferior muestra `Other user-thread entries on CPU2: 0`.
- OpenSSL y `single_thread_multiplier` permanecen activos durante las trazas.
- No aparecen mensajes `Non sensitized`, panic o reinicio inesperado.

Repetir la toma si el TID cambia, el programa termina antes de las mediciones, la referencia inicial solo muestra una CPU o se reserva por error el TID de `ttyin`.

## Notas de edición

- No cortar el momento en que `monopolize_state` muestra el TID asociado a CPU2.
- Se pueden acortar los dos intervalos de espera, pero conservar al menos una actualización parcial de cada DTrace.
- Mantener simultáneamente visibles la distribución final y el conteo de otros hilos.
- Si el panel inferior resulta difícil de leer en 1080p, ampliarlo durante la comparación final y volver después al encuadre completo.
- El speech puede grabarse posteriormente; las marcas de tiempo sirven como guía de montaje.

## Tabla rápida de comandos limpios

Ejecutar las filas de arriba hacia abajo. Cuando una fila contiene comandos en más de una columna, iniciar primero el comando de la terminal derecha superior y continuar inmediatamente con la terminal derecha inferior. Los comandos posteriores a la grabación aparecen separados al final.

<table>
  <thead>
    <tr>
      <th>Terminal izquierda — carga principal</th>
      <th>Terminal derecha superior — control y distribución</th>
      <th>Terminal derecha inferior — competencia y exclusión</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>—</td><td>uname -a</td><td>—</td></tr>
    <tr><td>—</td><td>sysctl kern.bootfile</td><td>—</td></tr>
    <tr><td>—</td><td>sysctl -d kern.sched_petri.monopolize</td><td>—</td></tr>
    <tr><td>—</td><td>sysctl kern.sched_petri.monopolize_state</td><td>—</td></tr>
    <tr><td>cd ~/freebsd-wiki/project_files/test_files/single_thread_multiplier</td><td>—</td><td>—</td></tr>
    <tr><td>./single_thread_multiplier</td><td>—</td><td>—</td></tr>
    <tr><td>—</td><td>procstat -at | grep single_thread_multi</td><td>—</td></tr>
    <tr><td>—</td><td>set WORKER_TID (procstat -at | awk '$3 == "single_thread_multi" && $7 == "run" {print $2; exit}')</td><td>—</td></tr>
    <tr><td>—</td><td>echo "WORKER_TID=$WORKER_TID"</td><td>—</td></tr>
    <tr><td>—</td><td>timeout 24 dtrace -s ~/dtrace-measurements/scripts/thread_cpu_distribution.d $WORKER_TID | tee /tmp/monopolization-before.txt</td><td>—</td></tr>
    <tr><td>—</td><td>sysctl kern.sched_petri.monopolize=$WORKER_TID:2</td><td>—</td></tr>
    <tr><td>—</td><td>sysctl kern.sched_petri.monopolize_state</td><td>—</td></tr>
    <tr><td>—</td><td>timeout 24 dtrace -s ~/dtrace-measurements/scripts/thread_cpu_distribution.d $WORKER_TID | tee /tmp/monopolization-after.txt</td><td>set WORKER_TID (procstat -at | awk '$3 == "single_thread_multi" && $7 == "run" {print $2; exit}')</td></tr>
    <tr><td>—</td><td>—</td><td>echo "WORKER_TID=$WORKER_TID"</td></tr>
    <tr><td>—</td><td>—</td><td>openssl speed -seconds 20 -bytes 8192 sha256 &> /tmp/monopolization-competing-openssl.txt &</td></tr>
    <tr><td>—</td><td>—</td><td>timeout 24 dtrace -s ~/dtrace-measurements/scripts/reserved_cpu_foreign_threads.d 2 $WORKER_TID | tee /tmp/monopolization-foreign.txt</td></tr>
    <tr><td>—</td><td>clear</td><td>—</td></tr>
    <tr><td>—</td><td>echo "ANTES: sin monopolización"</td><td>—</td></tr>
    <tr><td>—</td><td>awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/monopolization-before.txt</td><td>—</td></tr>
    <tr><td>—</td><td>echo "DESPUÉS: TID reservado en CPU2"</td><td>—</td></tr>
    <tr><td>—</td><td>awk -F, '/^cpu,/ {n[$2]=$3} END {for(i=0;i<4;i++) printf "CPU%d: %d\n",i,n[i]+0}' /tmp/monopolization-after.txt</td><td>awk -F, '/^total,/ {total=$2} END {printf "Other user-thread entries on CPU2: %d\n",total+0}' /tmp/monopolization-foreign.txt</td></tr>
    <tr><td>—</td><td>sysctl kern.sched_petri.monopolize_state</td><td>—</td></tr>
    <tr><td colspan="3"><strong>Después de detener la grabación</strong></td></tr>
    <tr><td>0</td><td>sysctl kern.sched_petri.monopolize=$WORKER_TID:2</td><td>—</td></tr>
    <tr><td>—</td><td>sysctl kern.sched_petri.monopolize_state</td><td>—</td></tr>
  </tbody>
</table>
