# Actualización a FreeBSD v11.0.1

> Se compara el archivo `sched_4bsd.c` con el mismo archivo de la versión 11.0.0_PI.

```diff
...
    #include <machine/pcb.h>
    #include <machine/smp.h>

+   #include <sys/sched_petri.h>
+
    #ifdef HWPMC_HOOKS
    #include <sys/pmckern.h>
    #endif
...
```

### Función `maybe_preempt`

```diff
...
    int maybe_preempt(struct thread *td)
    {
    #ifdef PREEMPTION
        struct thread *ctd;
        int cpri, pri;

+       struct td_sched *ts;
+       ts = td_get_sched(td);
+
...
```

### Función `sched_setup`

```diff
...
    static void
    sched_setup(void *dummy)
    {

        setup_runqs();
+       init_resource_net();
        /* Account for thread0. */
        sched_load_add();
    }
...
```

### Función `schedinit`

```diff
...
    void schedinit(void)
    {

        /*
        * Set up the scheduler specific parts of thread0.
        */
        thread0.td_lock = &sched_lock;
        td_get_sched(&thread0)->ts_slice = sched_slice;
        mtx_init(&sched_lock, "sched lock", NULL, MTX_SPIN | MTX_RECURSE);
+
+       int initial_mark_t0[PLACES_SIZE] = {0, 0, 0, 1, 0};
+       int i;
+       for (i = 0; i < PLACES_SIZE; i++)
+       {
+           thread0.mark[i] = initial_mark_t0[i];
+       }
    }
...
```

### Función `sched_switch`

```diff
...
    td->td_owepreempt = 0;
	td->td_oncpu = NOCPU;

+   resource_expulse_thread(td, flags);

	/*
...
```

```diff
...
        TD_SET_RUNNING(newtd);
		if ((newtd->td_flags & TDF_NOLOAD) == 0)
			sched_load_add();
+
+		if (ts->ts_runq != &runq)
+		{
+			resource_fire_net(newtd, TRAN_UNQUEUE + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
+		}
+		else
+		{
+			resource_fire_net(newtd, TRAN_FROM_GLOBAL_CPU + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
+		}
	}
	else
	{
		newtd = choosethread();
		MPASS(newtd->td_lock == &sched_lock);
	}

+	resource_execute_thread(newtd, PCPU_GET(cpuid));
+
	if (td != newtd)
	{
#ifdef HWPMC_HOOKS
...
```

### Función `sched_wakeup`

```diff
...
        td->td_slptick = 0;
        ts->ts_slptime = 0;
        ts->ts_slice = sched_slice;
+       // thread_petri_fire(td, TRAN_WAKEUP);
        sched_add(td, SRQ_BORING);
    }
...
```

### Función `sched_pickcpu`

```diff
...
    #ifdef SMP
    static int
    sched_pickcpu(struct thread *td)
    {
-       int best, cpu;
+       int transition, cpu;

        mtx_assert(&sched_lock, MA_OWNED);

-       if (td->td_lastcpu != NOCPU && THREAD_CAN_SCHED(td, td->td_lastcpu))
-           best = td->td_lastcpu;
+   	transition = resource_choose_cpu(td);
+   	if (transition == TRAN_QUEUE_GLOBAL)
+
+   		cpu = -1;
        else
-           best = NOCPU;
-       CPU_FOREACH(cpu)
-       {
-           if (!THREAD_CAN_SCHED(td, cpu))
-               continue;
-
-           if (best == NOCPU)
-               best = cpu;
-           else if (runq_length[cpu] < runq_length[best])
-               best = cpu;
-       }
-       KASSERT(best != NOCPU, ("no valid CPUs"));
-
-       return (best);
+		    cpu = (int)(transition / CPU_BASE_TRANSITIONS);
+
+	    return (cpu);
    }
    #endif
...
```

### Función `sched_add`

```diff
...
    void sched_add(struct thread *td, int flags)
    #ifdef SMP
    {
+       if (td && ((td)->td_frominh == 1))
+       {
+           thread_petri_fire(td, TRAN_WAKEUP);
+           td->td_frominh = 0;
+       }
+
        cpuset_t tidlemsk;
        struct td_sched *ts;
...
```

```diff
...
    /*
     * If SMP is started and the thread is pinned or otherwise limited to
     * a specific set of CPUs, queue the thread to a per-CPU run queue.
     * Otherwise, queue the thread to the global run queue.
     *
     * If SMP has not yet been started we must use the global run queue
     * as per-CPU state may not be initialized yet and we may crash if we
     * try to access the per-CPU run queues.
     */
-   if (smp_started && (td->td_pinned != 0 || td->td_flags & TDF_BOUND ||
-                   ts->ts_flags & TSF_AFFINITY))
-   {
-   if (td->td_pinned != 0)
-       cpu = td->td_lastcpu;
-   else if (td->td_flags & TDF_BOUND)
-   {
-       /* Find CPU from bound runq. */
-       KASSERT(SKE_RUNQ_PCPU(ts),
-               ("sched_add: bound td_sched not on cpu runq"));
-       cpu = ts->ts_runq - &runq_pcpu[0];
-   }
-   else
-       /* Find a valid CPU for our cpuset */
	cpu = sched_pickcpu(td);
+	if (cpu != NOCPU)
+	{
		ts->ts_runq = &runq_pcpu[cpu];
		single_cpu = 1;
-		CTR3(KTR_RUNQ,
-			 "sched_add: Put td_sched:%p(td:%p) on cpu%d runq", ts, td,
-			 cpu);
+		resource_fire_net(td, TRAN_ADDTOQUEUE + (cpu * CPU_BASE_TRANSITIONS));
	}
	else
	{
-		CTR2(KTR_RUNQ,
-			 "sched_add: adding td_sched:%p (td:%p) to gbl runq", ts,
-			 td);
-		cpu = NOCPU;
		ts->ts_runq = &runq;
+		resource_fire_net(td, TRAN_QUEUE_GLOBAL);
	}

	cpuid = PCPU_GET(cpuid);
...
```

### Función `sched_rem`

```diff
...
    #ifdef SMP
        if (ts->ts_runq != &runq)
+       {
            runq_length[ts->ts_runq - runq_pcpu]--;
+           resource_remove_thread(td, (ts->ts_runq - runq_pcpu));
+       }
+       else
+       {
+           resource_fire_net(td, TRAN_REMOVE_GLOBAL_QUEUE);
+       }
    #endif
        runq_remove(ts->ts_runq, td);
        TD_SET_CAN_RUN(td);
    }
...
```

### Función `sched_choose`

```diff
...
    /*
    * Select threads to run.  Note that running threads still consume a
    * slot.
    */
    struct thread *
    sched_choose(void)
    {
        struct thread *td;
        struct runq *rq;

        mtx_assert(&sched_lock, MA_OWNED);
    #ifdef SMP
        struct thread *tdcpu;

        rq = &runq;
        td = runq_choose_fuzz(&runq, runq_fuzz);
        tdcpu = runq_choose(&runq_pcpu[PCPU_GET(cpuid)]);

        if (td == NULL ||
            (tdcpu != NULL &&
            tdcpu->td_priority < td->td_priority))
        {
            CTR2(KTR_RUNQ, "choosing td %p from pcpu runq %d", tdcpu,
                PCPU_GET(cpuid));
            td = tdcpu;
            rq = &runq_pcpu[PCPU_GET(cpuid)];
+
+           if (td)
+           {
+               resource_fire_net(td, TRAN_UNQUEUE + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
+           }
        }
        else
        {
            CTR1(KTR_RUNQ, "choosing td_sched %p from main runq", td);
+           resource_fire_net(td, TRAN_FROM_GLOBAL_CPU + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
        }

    #else
        rq = &runq;
        td = runq_choose(&runq);
    #endif
        if (td)
        {
    #ifdef SMP
            if (td == tdcpu)
-           {
                runq_length[PCPU_GET(cpuid)]--;
-           }
    #endif
            runq_remove(rq, td);
            td->td_flags |= TDF_DIDRUN;

            KASSERT(td->td_flags & TDF_INMEM,
                    ("sched_choose: thread swapped out"));
            return (td);
        }
+       if (PCPU_GET(idlethread)->td_frominh == 1)
+       {
+           thread_petri_fire(PCPU_GET(idlethread), TRAN_WAKEUP);
+           PCPU_GET(idlethread)->td_frominh = 0;
+       }
+       resource_fire_net(PCPU_GET(idlethread), TRAN_QUEUE_GLOBAL);
+       resource_fire_net(PCPU_GET(idlethread), TRAN_FROM_GLOBAL_CPU + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
        return (PCPU_GET(idlethread));
    }
...
```

### Función `sched_throw`

```diff
...
    /*
    * A CPU is entering for the first time or a thread is exiting.
    */
    void sched_throw(struct thread *td)
    {
        /*
        * Correct spinlock nesting.  The idle thread context that we are
        * borrowing was created so that it would start out with a single
        * spin lock (sched_lock) held in fork_trampoline().  Since we've
        * explicitly acquired locks in this function, the nesting count
        * is now 2 rather than 1.  Since we are nested, calling
        * spinlock_exit() will simply adjust the counts without allowing
        * spin lock using code to interrupt us.
        */
        if (td == NULL)
        {
            mtx_lock_spin(&sched_lock);
            spinlock_exit();
            PCPU_SET(switchtime, cpu_ticks());
            PCPU_SET(switchticks, ticks);
        }
        else
        {
            lock_profile_release_lock(&sched_lock.lock_object);
            MPASS(td->td_lock == &sched_lock);
            td->td_lastcpu = td->td_oncpu;
            td->td_oncpu = NOCPU;
+           resource_expulse_thread(td, SW_VOL);
        }
        mtx_assert(&sched_lock, MA_OWNED);
        KASSERT(curthread->td_md.md_spinlock_count == 1, ("invalid count"));
+       struct thread *newtd;
+       newtd = choosethread();
+       resource_execute_thread(newtd, PCPU_GET(cpuid));
+       cpu_throw(td, newtd); /* doesn't return */
-       cpu_throw(td, choosethread()); /* doesn't return */
    }

```
