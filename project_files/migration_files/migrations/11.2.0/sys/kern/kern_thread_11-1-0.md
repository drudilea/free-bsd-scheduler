# Actualización a FreeBSD v11.2.0

> Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 11.1.0.

```diff
...
    #include <sys/rwlock.h>
    #include <sys/umtx.h>
+   #include <sys/vmmeter.h>
    #include <sys/cpuset.h>
    #ifdef	HWPMC_HOOKS
...
```

```diff
...

+    EVENTHANDLER_LIST_DEFINE(thread_ctor);
+    EVENTHANDLER_LIST_DEFINE(thread_dtor);
+    EVENTHANDLER_LIST_DEFINE(thread_init);
+    EVENTHANDLER_LIST_DEFINE(thread_fini);

...
```

### Función `thread_ctor`

```diff
...
        /*
        * Note that td_critnest begins life as 1 because the thread is not
        * running and is thereby implicitly waiting to be on the receiving
        * end of a context switch.
        */
        td->td_critnest = 1;
        td->td_lend_user_pri = PRI_MAX;
-       EVENTHANDLER_INVOKE(thread_ctor, td);
+	    EVENTHANDLER_DIRECT_INVOKE(thread_ctor, td);
    #ifdef AUDIT
        audit_thread_alloc(td);
    #endif
        umtx_thread_alloc(td);
        return (0);
    }
...
```

### Función `thread_dtor`

```diff
...
    /* Free all OSD associated to this thread. */
	osd_thread_exit(td);
	td_softdep_cleanup(td);
	MPASS(td->td_su == NULL);

-	EVENTHANDLER_INVOKE(thread_dtor, td);
+   EVENTHANDLER_DIRECT_INVOKE(thread_dtor, td);
	tid_free(td->td_tid);
...
```

### Función `thread_init`

```diff
...
    struct thread *td;

	td = (struct thread *)mem;

	td->td_sleepqueue = sleepq_alloc();
	td->td_turnstile = turnstile_alloc();
	td->td_rlqe = NULL;
-	EVENTHANDLER_INVOKE(thread_init, td);
+   EVENTHANDLER_DIRECT_INVOKE(thread_init, td);
	umtx_thread_init(td);
	td->td_kstack = 0;
	td->td_sel = NULL;
	return (0);
...
```

### Función `thread_fini`

```diff
...
    struct thread *td;

	td = (struct thread *)mem;
-	EVENTHANDLER_INVOKE(thread_fini, td);
+   EVENTHANDLER_DIRECT_INVOKE(thread_fini, td);
	rlqentry_free(td->td_rlqe);
	turnstile_free(td->td_turnstile);
	sleepq_free(td->td_sleepqueue);
	umtx_thread_fini(td);
	seltdfini(td);
...
```
