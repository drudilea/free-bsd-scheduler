# Actualización a FreeBSD v12.2.0

Se compara el archivo `sched_4bsd.c` con el mismo archivo de la versión 12.1.0.

### `KDTRACE_HOOKS`

> Commited comment
>
> > Mark some more hot global variables with \_\_read_mostly.

```diff
...
    #ifdef KDTRACE_HOOKS
    #include <sys/dtrace_bsd.h>
+   int __read_mostly		    dtrace_vtime_active;
-   int 		            dtrace_vtime_active;
    dtrace_vtime_switch_func_t      dtrace_vtime_switch_func;
    #endif
...
```
