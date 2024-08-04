# Cambiar resolución de la consola

Agregar en `/boot/loader.conf` la siguiente línea

```bash
kern.vty=sc
```

Para ver los modos de video disponibles para cada computadora

```bash
vidcontrol -i mode
```

Ejecutar el siguiente comando con el número correspondiente a la resolución deseada, para ver cambios en la resolución de la consola

```bash
vidcontrol MODE_279
```

Si el modo de video es aceptable, es posible dejarlo predefinido para cada inicio de la máquina. Para esto hay que editar el archivo `/etc/rc.conf`

```bash
allscreens_flags="MODE_279"
```
