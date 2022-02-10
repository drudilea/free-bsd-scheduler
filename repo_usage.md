## Repositorio del equipo de trabajo

El [repositorio del equipo de trabajo][repo-fork], consiste en un fork realizado sobre el [repositorio oficial de freebsd-src][repo-freebsd].

La modalidad de fork, permite mantener actualizado el repositorio con las últimas versiones del proyecto original, y al mismo tiempo consultar la version realizada por el proyecto integrador previo.

El próximo paso, luego de hacer el fork de la version oficial del repositorio de FreeBSD, fue crear una nueva rama a partir de `release/11.0.0` y aplicar manualmente los cambios realizados por Papp y Turina en los archivos correspondientes.

De esta forma, existe la posibilidad de hacer Fetch Upstreams cada vez que sea necesario e implementar el trabajo haciendo uso de las últimas versiones del S.O.

### Estrategia de Ramas

Consideramos de mucha utilidad, la definicion/normalización de un sistema de ramas, para poder así llevar más organizado nuestro trabajo y poder encontrar fácilmente el paso a paso de los avances del proyecto desde un comienzo hasta la finalización del mismo.

Para definir los nombres de las ramas, establecimos 3 casos principales por los cuales se crearían nuevas ramas.

- Testing: Para casos en los que únicamente se necesite hacer uso de logs para comprobar que alguna parte del codigo fuente esté funcionando como es deseado (o no).

- Update: Utilizado principalmente en la etapa inicial del proyecto integrador en la cual el objetivo era actualizar los cambios realizados por el proyecto integrador previo con las nuevas versiones existentes de FreeBSD.

- Feature: Estas ramas se utilizan para los casos en los que se agrega nuevo codigo o funcionalidades no existentes.

Con esots tres casos principales, se define la estrategia de nombrado de ramas de la siguente forma:

```
DrudiGoldmanPI/<CAUSA>_<DESCRIPCION>
```

En donde `<DESCRIPCION>` es una breve explicación del contenido de los cambios (en **cammelCase**).

<!-- Global variables -->

[repo-fork]: https://github.com/drudilea/freebsd-src/
[repo-freebsd]: https://github.com/freebsd/freebsd-src
