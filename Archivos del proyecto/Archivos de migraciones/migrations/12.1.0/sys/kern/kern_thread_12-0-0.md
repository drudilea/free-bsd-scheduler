# Actualización a FreeBSD v12.1.0

> Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 12.0.0.

### Función `thread_ctor`

```diff
...
        td = (struct thread *)mem;
        td->td_state = TDS_INACTIVE;
-       td->td_oncpu = NOCPU;
+       td->td_lastcpu = td->td_oncpu = NOCPU;

        td->td_tid = tid_alloc();
...
```
