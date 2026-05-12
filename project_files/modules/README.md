# Módulos históricos/deprecated

Esta carpeta conserva módulos de kernel usados en iteraciones anteriores:

- `toggle_active_cpu_km`
- `pin_threads`

Actualmente no son el mecanismo recomendado para probar la funcionalidad del
scheduler Petri.

## Por qué quedan deprecated

Estos módulos cargan acciones hardcodeadas al hacer `kldload`, por ejemplo:

- `toggle_active_cpu(0)`
- `toggle_pin_thread_to_cpu(100420, 2)`

Eso hacía que cada prueba dependiera de recompilar o editar el módulo para
cambiar CPU, thread id o cantidad de transiciones a imprimir. Además, al estar
separados del flujo de branches de testing, era fácil terminar probando código
viejo contra kernels nuevos.

## Reemplazo actual

Usar kernels de testing y controles `sysctl`:

- Encendido/apagado de CPU:

  ```sh
  sysctl kern.sched_petri.cpu_toggle=1
  ```

- Monopolización:

  ```sh
  sysctl kern.sched_petri.monopolize=<tid>:<cpu>
  ```

Los comandos completos de validación están en
[`../../tests/current_scheduler_testing.md`](../../tests/current_scheduler_testing.md).

## Cómo tratarlos

- No eliminarlos: son material histórico útil para reconstruir iteraciones.
- No usarlos para validar comportamiento actual.
- No basar nuevos tests en `kldload`/`kldunload` de estos módulos.
- Si se necesita un nuevo control de testing, preferir una branch `testing/*`
  con sysctl explícito y comandos reproducibles.
