# Actualización a FreeBSD v12.2.0

Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 12.1.0.

### Función `tdfind`

> Commited comment:
>
> > Short-circuit tdfind when looking for the calling thread.

```diff
...
    /* Locate a thread by number; return with proc lock held. */
    struct thread *
    tdfind(lwpid_t tid, pid_t pid)
    {
    #define RUN_THRESH	16
        struct thread *td;
        int run = 0;

+       td = curthread;
+       if (td->td_tid == tid) {
+       	if (pid != -1 && td->td_proc->p_pid != pid)
+       		return (NULL);
+       	PROC_LOCK(td->td_proc);
+       	return (td);
+       }

        rw_rlock(&tidhash_lock);
...
```

### Función `thread_check_susp`

> Commited comment:
>
> > Rename umtxq_check_susp() to thread_check_susp() (and move directory to sys/kern/kern_umtx.c).

```diff
...
+   /*
+    * Check for possible stops and suspensions while executing a
+    * casueword or similar transiently failing operation.
+    *
+    * The sleep argument controls whether the function can handle a stop
+    * request itself or it should return ERESTART and the request is
+    * proceed at the kernel/user boundary in ast.
+    *
+    * Typically, when retrying due to casueword(9) failure (rv == 1), we
+    * should handle the stop requests there, with exception of cases when
+    * the thread owns a kernel resource, for instance busied the umtx
+    * key, or when functions return immediately if thread_check_susp()
+    * returned non-zero.  On the other hand, retrying the whole lock
+    * operation, we better not stop there but delegate the handling to
+    * ast.
+    *
+    * If the request is for thread termination P_SINGLE_EXIT, we cannot
+    * handle it at all, and simply return EINTR.
+    */
+   int
+   thread_check_susp(struct thread *td, bool sleep)
+   {
+   	struct proc *p;
+   	int error;
+
+   	/*
+   	 * The check for TDF_NEEDSUSPCHK is racy, but it is enough to
+   	 * eventually break the lockstep loop.
+   	 */
+   	if ((td->td_flags & TDF_NEEDSUSPCHK) == 0)
+   		return (0);
+   	error = 0;
+   	p = td->td_proc;
+   	PROC_LOCK(p);
+   	if (p->p_flag & P_SINGLE_EXIT)
+   		error = EINTR;
+   	else if (P_SHOULDSTOP(p) ||
+   	    ((p->p_flag & P_TRACED) && (td->td_dbgflags & TDB_SUSPEND)))
+   		error = sleep ? thread_suspend_check(0) : ERESTART;
+   	PROC_UNLOCK(p);
+   	return (error);
+   }
...
```
