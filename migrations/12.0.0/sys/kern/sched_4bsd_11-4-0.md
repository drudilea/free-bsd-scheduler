# Actualización a FreeBSD v12.0.0

> Se compara el archivo `sched_4bsd.c` con el mismo archivo de la versión 11.4.0.

```diff
...
    struct pcpuidlestat
    {
        u_int idlecalls;
        u_int oldidlecalls;
    };
-   static DPCPU_DEFINE(struct pcpuidlestat, idlestat);
+   DPCPU_DEFINE_STATIC(struct pcpuidlestat, idlestat);
...
```

### Función `sched_fork_thread`

```diff
...
    void sched_fork_thread(struct thread *td, struct thread *childtd)
    {
        struct td_sched *ts, *tsc;

        childtd->td_oncpu = NOCPU;
        childtd->td_lastcpu = NOCPU;
        childtd->td_lock = &sched_lock;
        childtd->td_cpuset = cpuset_ref(td->td_cpuset);
+       childtd->td_domain.dr_policy = td->td_cpuset->cs_domain;
        childtd->td_priority = childtd->td_base_pri;
        ts = td_get_sched(childtd);
        bzero(ts, sizeof(*ts));
        tsc = td_get_sched(td);
        ts->ts_estcpu = tsc->ts_estcpu;
        ts->ts_flags |= (tsc->ts_flags & TSF_AFFINITY);
        ts->ts_slice = 1;
    }
...
```

### Función `sched_userret`

```diff
...
-   void sched_userret(struct thread *td)
+   void sched_userret_slowpath(struct thread *td)
    {
-       /*
-       * XXX we cheat slightly on the locking here to avoid locking in
-       * the usual case.  Setting td_priority here is essentially an
-       * incomplete workaround for not setting it properly elsewhere.
-       * Now that some interrupt handlers are threads, not setting it
-       * properly elsewhere can clobber it in the window between setting
-       * it here and returning to user mode, so don't waste time setting
-       * it perfectly here.
-       */
-       KASSERT((td->td_flags & TDF_BORROWING) == 0,
-               ("thread with borrowed priority returning to userland"));
-       if (td->td_priority != td->td_user_pri)
-       {
            thread_lock(td);
            td->td_priority = td->td_user_pri;
            td->td_base_pri = td->td_user_pri;
            thread_unlock(td);
-       }
    }
...
```
