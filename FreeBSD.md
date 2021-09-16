Create a copy a `rc.conf` file

```bash
cp /etc/rc.conf /etc/rc.conf.original
```

Check network adapter name that belongs to Ethernet interface

```bash
ifconfig
```

Update packages

```bash
pkg update && pkg upgrade
```

Versions mismatch, don't worry, always Yes

```bash
pkg install git
```

Kernel found at `/usr/src`

```bash
ls -a /usr/src
```

## Documentación

- [Repositorio Nicolas Papp][nicolaspapp repo]

<!-- Global variables -->

[nicolaspapp repo]: https://github.com/nicolaspapp/freebsd/wiki/Compilaci%C3%B3n-del-Kernel-de-FreeBSD-en-modo-Debug
