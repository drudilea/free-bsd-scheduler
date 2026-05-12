# Wiki de la tesis

Este repositorio contiene documentación, material histórico, modelos, scripts y
notas de trabajo de la tesis sobre el scheduler de FreeBSD basado en Redes de
Petri.

## Estado actual

El flujo de trabajo actual ya no usa los módulos `.ko` históricos para activar
las funcionalidades de prueba. Las funcionalidades de encendido/apagado de CPU y
monopolización se validan con kernels de testing específicos y controles por
`sysctl`.

Los módulos ubicados en `project_files/modules/` quedan documentados como
material histórico/deprecated. Pueden servir para entender cómo se probaban las
primeras iteraciones, pero no deben usarse como mecanismo principal de testing.

## Documentos útiles

- [`tests/current_scheduler_testing.md`](tests/current_scheduler_testing.md): comandos actuales para boot, verificación,
  toggles, monopolización y pruebas de carga.
- [`project_files/modules/README.md`](project_files/modules/README.md): estado deprecado de los módulos `.ko` y
  reemplazos actuales.
- [`utils/kernel_compilation.md`](utils/kernel_compilation.md): compilación e instalación de kernels de prueba.
- [`utils/remote_debug.md`](utils/remote_debug.md): debugging remoto/kernel debugger.
- [`tests/tests.md`](tests/tests.md): referencia histórica de plazas, transiciones e invariantes.

## Nota para actualizar la tesis

Algunas secciones del documento principal todavía pueden usar la palabra
"módulos" para describir las funcionalidades de encendido/apagado y
monopolización. Esa idea sigue siendo útil a nivel conceptual, pero el mecanismo
de validación actual no son módulos `.ko`: son branches/kernels de testing con
sysctls reproducibles.

## Repositorios involucrados

- Repo de código FreeBSD: `freebsd-src`.
- Este wiki: repo Git independiente dentro de `thesis-wiki/wiki-repo`.
- La carpeta padre `thesis-wiki/` suele estar ignorada por el repo de FreeBSD,
  pero este wiki tiene su propio historial Git.
