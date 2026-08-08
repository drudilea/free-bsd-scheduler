#!/usr/sbin/dtrace -s

/*
 * Historical scheduler diagnostic intended to correlate on-cpu and off-cpu
 * events and print the CPU, thread ID, and priority of the departing thread.
 *
 * IMPORTANT: this script is not used by the current quantitative validation.
 * Variables under this-> are clause-local in DTrace, so values assigned in an
 * on-cpu clause do not persist into a later off-cpu clause. The code is kept
 * unchanged as historical material, but it should not be used as evidence for
 * the inhibition or monopolization demos. Use cpu_distribution.d,
 * thread_cpu_distribution.d, or reserved_cpu_foreign_threads.d instead.
 */

/* Limit dynamic-variable memory used by clause-local variables. */
#pragma D option dynvarsize=2m

/*
 * Intended to remember the CPU for a later off-cpu event. Because this->cpu is
 * clause-local, the value is discarded when this probe clause finishes.
 */
sched:::on-cpu
{
    this->cpu = cpu;
}

/*
 * Intended to report an idle CPU. This clause cannot reliably read the value
 * assigned by the preceding on-cpu clause because it has a separate scope.
 */
sched:::off-cpu
/this->cpu != -1/
{
    printf("CPU %d was idle.\n", this->cpu);
    this->cpu = -1;
}

/*
 * Intended to capture CPU, TID, and scheduler priority for the current thread.
 * args[0] is interpreted here as the priority exposed by the scheduler probe.
 */
sched:::on-cpu
{
    this->cpu = cpu;
    this->tid = tid;
    this->prio = args[0];
}

/*
 * Intended to print the values captured above. The separate clause-local scope
 * means the values are not preserved across the two scheduler probes.
 */
sched:::off-cpu
/this->cpu != -1/
{
    printf("CPU %d: Thread ID %d, Priority %d\n", this->cpu, this->tid, this->prio);
    this->cpu = -1;
}
