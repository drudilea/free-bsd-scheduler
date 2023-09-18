# Actualización a FreeBSD v11.0.1

> Se compara el archivo `kern_thread.c` con el mismo archivo de la versión 11.0.0_PI.

```diff
...
    #include <sys/mutex.h>
    #include <sys/proc.h>
+   #include <sys/sched_petri.h>
    #include <sys/rangelock.h>
    #include <sys/resourcevar.h>
...
```

### Función `thread_alloc`

```diff
...
    /*
    * Allocate a thread.
    */
    struct thread *
    thread_alloc(int pages)
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
        vm_domain_policy_init(&td->td_vm_dom_policy);
+       init_petri_thread(td);
        return (td);
    }
...
```
