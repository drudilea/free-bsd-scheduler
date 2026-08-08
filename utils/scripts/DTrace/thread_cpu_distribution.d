#!/usr/sbin/dtrace -s

/*
 * Measure how sched:::on-cpu events for one selected TID are distributed
 * across CPUs.
 *
 * Usage:
 *   dtrace -s thread_cpu_distribution.d <tid>
 *
 * Argument:
 *   $1 - TID to observe.
 *
 * The script prints cumulative summaries every five seconds and a final
 * cumulative summary on exit. A CPU with no matching events is omitted by
 * printa(); callers may normalize a missing row to zero.
 */

/* Suppress DTrace's default probe and status messages. */
#pragma D option quiet

/* Reserve additional dynamic-variable memory for the aggregations below. */
#pragma D option dynvarsize=16m

/* Echo the selected TID before scheduler events are collected. */
dtrace:::BEGIN
{
    printf("CPU distribution for tid %d\n", $1);
}

/* Count every time the selected TID starts or resumes execution on a CPU. */
sched:::on-cpu
/tid == $1/
{
    /* Per-CPU cumulative event count. */
    @by_cpu[cpu] = count();

    /* Cumulative count across all CPUs. */
    @total = count();
}

/* Print a cumulative progress snapshot every five seconds. */
tick-5s
{
    printf("\nPartial summary\n");
    printa("cpu,%d,%@d\n", @by_cpu);
    printa("total,%@d\n", @total);
}

/* Print the final cumulative aggregations when DTrace is stopped. */
dtrace:::END
{
    printf("\nFinal summary\n");
    printa("cpu,%d,%@d\n", @by_cpu);
    printa("total,%@d\n", @total);
}
