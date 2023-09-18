# Actualización a FreeBSD v11.1.0

> Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 11.0.1.

```diff
...

+   /*
+   * Asserts below verify the stability of struct thread and struct proc
+   * layout, as exposed by KBI to modules.  On head, the KBI is allowed
+   * to drift, change to the structures must be accompanied by the
+   * assert update.
+   *
+   * On the stable branches after KBI freeze, conditions must not be
+   * violated.  Typically new fields are moved to the end of the
+   * structures.
+   */
+   #ifdef __amd64__
+   _Static_assert(offsetof(struct thread, td_flags) == 0xe4,
+               "struct thread KBI td_flags");
+   _Static_assert(offsetof(struct thread, td_pflags) == 0xec,
+               "struct thread KBI td_pflags");
+   _Static_assert(offsetof(struct thread, td_frame) == 0x418,
+               "struct thread KBI td_frame");
+   _Static_assert(offsetof(struct thread, td_emuldata) == 0x4c0,
+               "struct thread KBI td_emuldata");
+   _Static_assert(offsetof(struct proc, p_flag) == 0xb0,
+               "struct proc KBI p_flag");
+   _Static_assert(offsetof(struct proc, p_pid) == 0xbc,
+               "struct proc KBI p_pid");
+   _Static_assert(offsetof(struct proc, p_filemon) == 0x3c0,
+               "struct proc KBI p_filemon");
+   _Static_assert(offsetof(struct proc, p_comm) == 0x3d0,
+               "struct proc KBI p_comm");
+   _Static_assert(offsetof(struct proc, p_emuldata) == 0x4a0,
+               "struct proc KBI p_emuldata");
+   #endif
+   #ifdef __i386__
+   _Static_assert(offsetof(struct thread, td_flags) == 0x8c,
+               "struct thread KBI td_flags");
+   _Static_assert(offsetof(struct thread, td_pflags) == 0x94,
+               "struct thread KBI td_pflags");
+   _Static_assert(offsetof(struct thread, td_frame) == 0x2c0,
+               "struct thread KBI td_frame");
+   _Static_assert(offsetof(struct thread, td_emuldata) == 0x30c,
+               "struct thread KBI td_emuldata");
+   _Static_assert(offsetof(struct proc, p_flag) == 0x68,
+               "struct proc KBI p_flag");
+   _Static_assert(offsetof(struct proc, p_pid) == 0x74,
+               "struct proc KBI p_pid");
+   _Static_assert(offsetof(struct proc, p_filemon) == 0x268,
+               "struct proc KBI p_filemon");
+   _Static_assert(offsetof(struct proc, p_comm) == 0x274,
+               "struct proc KBI p_comm");
+   _Static_assert(offsetof(struct proc, p_emuldata) == 0x2f4,
+               "struct proc KBI p_emuldata");
+   #endif

...
```

### Función `thread_dtor`

```diff
...
    #endif
        /* Free all OSD associated to this thread. */
        osd_thread_exit(td);
+       td_softdep_cleanup(td);
+       MPASS(td->td_su == NULL);

        EVENTHANDLER_INVOKE(thread_dtor, td);
        tid_free(td->td_tid);
...
```

### Función `threadinit`

```diff
...
    /*
    * Initialize global thread allocation resources.
    */
    void threadinit(void)
    {

        mtx_init(&tid_lock, "TID lock", NULL, MTX_DEF);

        /*
        * pid_max cannot be greater than PID_MAX.
        * leave one number for thread0.
        */
        tid_unrhdr = new_unrhdr(PID_MAX + 2, INT_MAX, &tid_lock);

        thread_zone = uma_zcreate("THREAD", sched_sizeof_thread(),
                                thread_ctor, thread_dtor, thread_init, thread_fini,
-                               16 - 1, UMA_ZONE_NOFREE);
+                               32 - 1, UMA_ZONE_NOFREE);
        tidhashtbl = hashinit(maxproc / 2, M_TIDHASH, &tidhash);
        rw_init(&tidhash_lock, "tidhash");
    }
...
```

### Función `thread_free`

```diff
...
   /*
    * Deallocate a thread.
    */
    void thread_free(struct thread *td)
    {

        lock_profile_thread_exit(td);
        if (td->td_cpuset)
            cpuset_rel(td->td_cpuset);
        td->td_cpuset = NULL;
        cpu_thread_free(td);
        if (td->td_kstack != 0)
            vm_thread_dispose(td);
        vm_domain_policy_cleanup(&td->td_vm_dom_policy);
+       callout_drain(&td->td_slpcallout);
        uma_zfree(thread_zone, td);
    }
...
```

### Función `thread_exit`

```diff
...
        KASSERT(p != NULL, ("thread exiting without a process"));
        CTR3(KTR_PROC, "thread_exit: thread %p (pid %ld, %s)", td,
            (long)p->p_pid, td->td_name);
+       SDT_PROBE0(proc, , , lwp__exit);
        KASSERT(TAILQ_EMPTY(&td->td_sigqueue.sq_list), ("signal pending"));

    #ifdef AUDIT
        AUDIT_SYSCALL_EXIT(0, td);
    #endif
...
```

### Función `thread_wait`

```diff
...
    /*
     * Do any thread specific cleanups that may be needed in wait()
     * called with Giant, proc and schedlock not held.
     */
    void thread_wait(struct proc *p)
    {
        struct thread *td;

        mtx_assert(&Giant, MA_NOTOWNED);
        KASSERT(p->p_numthreads == 1, ("multiple threads in thread_wait()"));
        KASSERT(p->p_exitthreads == 0, ("p_exitthreads leaking"));
        td = FIRST_THREAD_IN_PROC(p);
        /* Lock the last thread so we spin until it exits cpu_throw(). */
        thread_lock(td);
        thread_unlock(td);
        lock_profile_thread_exit(td);
        cpuset_rel(td->td_cpuset);
        td->td_cpuset = NULL;
        cpu_thread_clean(td);
        thread_cow_free(td);
+       callout_drain(&td->td_slpcallout);
        thread_reap(); /* check for zombie threads etc. */
    }
...
```
