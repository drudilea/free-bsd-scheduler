# Actualización a FreeBSD v11.2.0

> Se compara el archivo `sched_4bsd.c` con el mismo archivo de la versión 11.1.0.

### Función `schedcpu`

```diff
...
    /*
    * Recompute process priorities, every hz ticks.
    * MP-safe, called without the Giant mutex.
    */
    /* ARGSUSED */
    static void
    schedcpu(void)
    {
-       register fixpt_t loadfac = loadfactor(averunnable.ldavg[0]);
+       fixpt_t loadfac = loadfactor(averunnable.ldavg[0]);
        struct thread *td;
        struct proc *p;
        struct td_sched *ts;
        int awake;
...
```
