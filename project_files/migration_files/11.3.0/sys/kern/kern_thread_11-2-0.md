# Actualización a FreeBSD v11.3.0

> Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 11.2.0.

### Función `thread_exit`

```diff
...
        KASSERT(p != NULL, ("thread exiting without a process"));
        CTR3(KTR_PROC, "thread_exit: thread %p (pid %ld, %s)", td,
            (long)p->p_pid, td->td_name);
        SDT_PROBE0(proc, , , lwp__exit);
        KASSERT(TAILQ_EMPTY(&td->td_sigqueue.sq_list), ("signal pending"));

-   #ifdef AUDIT
-       AUDIT_SYSCALL_EXIT(0, td);
-   #endif
        /*
        * drop FPU & debug register state storage, or any other
        * architecture specific resources that
        * would not be on a new untouched process.
        */
        cpu_thread_exit(td);
...
```
