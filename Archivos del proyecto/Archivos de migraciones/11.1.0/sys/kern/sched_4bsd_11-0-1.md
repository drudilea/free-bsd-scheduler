# Actualización a FreeBSD v11.1.0

> Se compara el archivo `sched_4bsd.c` con el mismo archivo de la versión 11.0.1.

### Función `maybe_preempt`

```diff
...
    /*
     * This function is called when a thread is about to be put on run queue
     * because it has been made runnable or its priority has been adjusted.
-    * It determines if the new thread should be immediately preempted to.  If so,
-    * it switches to it and eventually returns true.  If not, it returns false
-    * so that the caller may place the thread on an appropriate run queue.
+    * It determines if the new thread should preempt the current thread.  If so,
+    * it sets td_owepreempt to request a preemption.
     */
    int maybe_preempt(struct thread *td)
    {
    #ifdef PREEMPTION
        struct thread *ctd;
        int cpri, pri;

        /*
         * The new thread should not preempt the current thread if any of the
         * following conditions are true:
         *
         *  - The kernel is in the throes of crashing (panicstr).
         *  - The current thread has a higher (numerically lower) or
         *    equivalent priority.  Note that this prevents curthread from
         *    trying to preempt to itself.
-        *  - It is too early in the boot for context switches (cold is set).
         *  - The current thread has an inhibitor set or is in the process of
         *    exiting.  In this case, the current thread is about to switch
         *    out anyways, so there's no point in preempting.  If we did,
         *    the current thread would not be properly resumed as well, so
         *    just avoid that whole landmine.
         *  - If the new thread's priority is not a realtime priority and
         *    the current thread's priority is not an idle priority and
         *    FULL_PREEMPTION is disabled.
         *
         * If all of these conditions are false, but the current thread is in
         * a nested critical section, then we have to defer the preemption
         * until we exit the critical section.  Otherwise, switch immediately
         * to the new thread.
         */
        ctd = curthread;
        THREAD_LOCK_ASSERT(td, MA_OWNED);
        KASSERT((td->td_inhibitors == 0),
                ("maybe_preempt: trying to run inhibited thread"));
        pri = td->td_priority;
        cpri = ctd->td_priority;
-       if (panicstr != NULL || pri >= cpri || cold /* || dumping */ ||
+       if (panicstr != NULL || pri >= cpri /* || dumping */ ||
            TD_IS_INHIBITED(ctd))
            return (0);
    #ifndef FULL_PREEMPTION
        if (pri > PRI_MAX_ITHD && cpri < PRI_MIN_IDLE)
            return (0);
    #endif
-       if (ctd->td_critnest > 1)
-	    {
-           CTR1(KTR_PROC, "maybe_preempt: in critical section %d", ctd->td_critnest);
+           CTR0(KTR_PROC, "maybe_preempt: scheduling preemption");
            ctd->td_owepreempt = 1;
-           return (0);
-       }
-       /*
-        * Thread is runnable but not yet put on system run queue.
-        */
-       MPASS(ctd->td_lock == td->td_lock);
-       MPASS(TD_ON_RUNQ(td));
-       TD_SET_RUNNING(td);
-       CTR3(KTR_PROC, "preempting to thread %p (pid %d, %s)\n", td,
-           td->td_proc->p_pid, td->td_name);
-       mi_switch(SW_INVOL | SW_PREEMPT | SWT_PREEMPT, td);
-       /*
-        * td's lock pointer may have changed.  We have to return with it
-        * locked.
-        */
-       spinlock_enter();
-       thread_unlock(ctd);
-       thread_lock(td);
-       spinlock_exit();
        return (1);
    #else
        return (0);
    #endif
    }
...
```

### Función `sched_switch`

```diff
...
    /*
	 * Switch to the sched lock to fix things up and pick
	 * a new thread.
	 * Block the td_lock in order to avoid breaking the critical path.
	 */
	if (td->td_lock != &sched_lock)
	{
		mtx_lock_spin(&sched_lock);
		tmtx = thread_lock_block(td);
	}

	if ((td->td_flags & TDF_NOLOAD) == 0)
		sched_load_rem();

	td->td_lastcpu = td->td_oncpu;
-   preempted = !((td->td_flags & TDF_SLICEEND) ||
-				  (flags & SWT_RELINQUISH));
+	preempted = (td->td_flags & TDF_SLICEEND) == 0 &&
+				(flags & SW_PREEMPT) != 0;
	td->td_flags &= ~(TDF_NEEDRESCHED | TDF_SLICEEND);
	td->td_owepreempt = 0;
	td->td_oncpu = NOCPU;
...
```

```diff
...
        else
        {
            newtd = choosethread();
            MPASS(newtd->td_lock == &sched_lock);
        }

+   #if (KTR_COMPILE & KTR_SCHED) != 0
+       if (TD_IS_IDLETHREAD(td))
+           KTR_STATE1(KTR_SCHED, "thread", sched_tdname(td), "idle",
+                   "prio:%d", td->td_priority);
+       else
+           KTR_STATE3(KTR_SCHED, "thread", sched_tdname(td), KTDSTATE(td),
+                   "prio:%d", td->td_priority, "wmesg:\"%s\"", td->td_wmesg,
+                   "lockname:\"%s\"", td->td_lockname);
+   #endif

        if (td != newtd)
...
```

```diff
...
    #endif
        }
        else
            SDT_PROBE0(sched, , , remain__cpu);

+        KTR_STATE1(KTR_SCHED, "thread", sched_tdname(td), "running",
+                "prio:%d", td->td_priority);

    #ifdef SMP
        if (td->td_flags & TDF_IDLETD)
            CPU_SET(PCPU_GET(cpuid), &idle_cpus_mask);
...
```

### Función `forward_wakeup`

```diff
...
    if ((!forward_wakeup_enabled) ||
            (forward_wakeup_use_mask == 0 && forward_wakeup_use_loop == 0))
            return (0);
-       if (!smp_started || cold || panicstr)
+       if (!smp_started || panicstr)
            return (0);

        forward_wakeups_requested++;
...
```

### Función `sched_add`

```diff
...
	else
	{
		CTR2(KTR_RUNQ,
			 "sched_add: adding td_sched:%p (td:%p) to gbl runq", ts,
			 td);
		cpu = NOCPU;
		ts->ts_runq = &runq;
	}

+	if ((td->td_flags & TDF_NOLOAD) == 0)
+		sched_load_add();
+	runq_add(ts->ts_runq, td, flags);
+	if (cpu != NOCPU)
+		runq_length[cpu]++;

	cpuid = PCPU_GET(cpuid);
...
```

```diff
...
+           if (!forwarded)
            {
-               if ((flags & SRQ_YIELDING) == 0 && maybe_preempt(td))
-			        return;
-		        else
+               if (!maybe_preempt(td))
                    maybe_resched(td);
            }
        }
    }
    #else  /* SMP */
...
```

```diff
...
        td_sched:%p (td:%p) to runq", ts, td);
        ts->ts_runq = &runq;

-       /*
-        * If we are yielding (on the way out anyhow) or the thread
-        * being saved is US, then don't try be smart about preemption
-        * or kicking off another CPU as it won't help and may hinder.
-        * In the YIEDLING case, we are about to run whoever is being
-        * put in the queue anyhow, and in the OURSELF case, we are
-        * putting ourself on the run queue which also only happens
-        * when we are about to yield.
-        */
-       if ((flags & SRQ_YIELDING) == 0)
-       {
-           if (maybe_preempt(td))
-               return;
-       }
        if ((td->td_flags & TDF_NOLOAD) == 0)
            sched_load_add();
        runq_add(ts->ts_runq, td, flags);
+       if (!maybe_preempt(td))
            maybe_resched(td);
    }
    #endif /* SMP */
...
```

### Función `sched_fork_exit`

```diff
    void sched_fork_exit(struct thread *td)
    {

        /*
        * Finish setting up thread glue so that it begins execution in a
        * non-nested critical section with sched_lock held but not recursed.
        */
        td->td_oncpu = PCPU_GET(cpuid);
        sched_lock.mtx_lock = (uintptr_t)td;
        lock_profile_obtain_lock_success(&sched_lock.lock_object,
                                        0, 0, __FILE__, __LINE__);
        THREAD_LOCK_ASSERT(td, MA_OWNED | MA_NOTRECURSED);

+       KTR_STATE1(KTR_SCHED, "thread", sched_tdname(td), "running",
+               "prio:%d", td->td_priority);
+       SDT_PROBE0(sched, , , on__cpu);
    }
```
