# Actualización a FreeBSD v12.0.0

> Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 11.4.0.

```diff
...
    #ifdef __amd64__
-   _Static_assert(offsetof(struct thread, td_flags) == 0xe4,
+   _Static_assert(offsetof(struct thread, td_flags) == 0xfc,
        "struct thread KBI td_flags");
-   _Static_assert(offsetof(struct thread, td_pflags) == 0xec,
+   _Static_assert(offsetof(struct thread, td_pflags) == 0x104,
        "struct thread KBI td_pflags");
-   _Static_assert(offsetof(struct proc, p_filemon) == 0x418,
+   _Static_assert(offsetof(struct thread, td_frame) == 0x470,
        "struct thread KBI td_frame");
-   _Static_assert(offsetof(struct thread, td_emuldata) == 0x4c0,
+   _Static_assert(offsetof(struct thread, td_emuldata) == 0x528,
        "struct thread KBI td_emuldata");
    _Static_assert(offsetof(struct proc, p_flag) == 0xb0,
        "struct proc KBI p_flag");
    _Static_assert(offsetof(struct proc, p_pid) == 0xbc,
        "struct proc KBI p_pid");
-   _Static_assert(offsetof(struct proc, p_filemon) == 0x3c0,
+   _Static_assert(offsetof(struct proc, p_filemon) == 0x3d0,
        "struct proc KBI p_filemon");
-   _Static_assert(offsetof(struct proc, p_comm) == 0x3d0,
+   _Static_assert(offsetof(struct proc, p_comm) == 0x3e4,
        "struct proc KBI p_comm");
-   _Static_assert(offsetof(struct proc, p_emuldata) == 0x4a0,
+   _Static_assert(offsetof(struct proc, p_emuldata) == 0x4b8,
        "struct proc KBI p_emuldata");
    #endif
    #ifdef __i386__
-   _Static_assert(offsetof(struct thread, td_flags) == 0x8c,
+   _Static_assert(offsetof(struct thread, td_flags) == 0x98,
        "struct thread KBI td_flags");
-   _Static_assert(offsetof(struct thread, td_pflags) == 0x94,
+   _Static_assert(offsetof(struct thread, td_pflags) == 0xa0,
        "struct thread KBI td_pflags");
-   _Static_assert(offsetof(struct thread, td_frame) == 0x2c0,
+   _Static_assert(offsetof(struct thread, td_frame) == 0x2e8,
        "struct thread KBI td_frame");
-   _Static_assert(offsetof(struct thread, td_emuldata) == 0x30c,
+   _Static_assert(offsetof(struct thread, td_emuldata) == 0x334,
        "struct thread KBI td_emuldata");
    _Static_assert(offsetof(struct proc, p_flag) == 0x68,
        "struct proc KBI p_flag");
    _Static_assert(offsetof(struct proc, p_pid) == 0x74,
        "struct proc KBI p_pid");
-   _Static_assert(offsetof(struct proc, p_filemon) == 0x268,
+   _Static_assert(offsetof(struct proc, p_filemon) == 0x27c,
        "struct proc KBI p_filemon");
-   _Static_assert(offsetof(struct proc, p_comm) == 0x274,
+   _Static_assert(offsetof(struct proc, p_comm) == 0x28c,
        "struct proc KBI p_comm");
-   _Static_assert(offsetof(struct proc, p_emuldata) == 0x2f4,
+   _Static_assert(offsetof(struct proc, p_emuldata) == 0x318,
        "struct proc KBI p_emuldata");
    #endif
...
```

### Función `thread_alloc`

```diff
...
    struct thread * thread_alloc(int pages)
    {
        struct thread *td;

        thread_reap(); /* check if any zombies to get */

        td = (struct thread *)uma_zalloc(thread_zone, M_WAITOK);
        KASSERT(td->td_kstack == 0, ("thread_alloc got thread with kstack"));
        if (!vm_thread_new(td, pages)) {
            uma_zfree(thread_zone, td);
            return (NULL);
        }
        cpu_thread_alloc(td);
-       vm_domain_policy_init(&td->td_vm_dom_policy);
        return (td);
    }
...
```

### Función `thread_free`

```diff
...
    void thread_free(struct thread *td)
    {

        lock_profile_thread_exit(td);
        if (td->td_cpuset)
            cpuset_rel(td->td_cpuset);
        td->td_cpuset = NULL;
        cpu_thread_free(td);
        if (td->td_kstack != 0)
            vm_thread_dispose(td);
-       vm_domain_policy_cleanup(&td->td_vm_dom_policy);
        callout_drain(&td->td_slpcallout);
        uma_zfree(thread_zone, td);
    }
...
```

### Función `thread_exit`

```diff
...
    #ifdef HWPMC_HOOKS
        /*
        * If this thread is part of a process that is being tracked by hwpmc(4),
        * inform the module of the thread's impending exit.
        */
        if (PMC_PROC_IS_USING_PMCS(td->td_proc))
+       {
            PMC_SWITCH_CONTEXT(td, PMC_FN_CSW_OUT);
+           PMC_CALL_HOOK_UNLOCKED(td, PMC_FN_THR_EXIT, NULL);
+       }
+       else if (PMC_SYSTEM_SAMPLING_ACTIVE())
+           PMC_CALL_HOOK_UNLOCKED(td, PMC_FN_THR_EXIT_LOG, NULL);
    #endif
        PROC_UNLOCK(p);
        PROC_STATLOCK(p);
        thread_lock(td);
        PROC_SUNLOCK(p);

        /* Do the same timestamp bookkeeping that mi_switch() would do. */
        new_switchtime = cpu_ticks();
        runtime = new_switchtime - PCPU_GET(switchtime);
        td->td_runtime += runtime;
        td->td_incruntime += runtime;
        PCPU_SET(switchtime, new_switchtime);
        PCPU_SET(switchticks, ticks);
-       PCPU_INC(cnt.v_swtch);
+       VM_CNT_INC(v_swtch);

        /* Save our resource usage in our process. */

...
```
