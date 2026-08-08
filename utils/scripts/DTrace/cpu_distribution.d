#!/usr/sbin/dtrace -s

/*
 * Measure how sched:::on-cpu events for OpenSSL are distributed across CPUs.
 *
 * Usage:
 *   dtrace -s cpu_distribution.d
 *
 * The script prints cumulative summaries every five seconds and a final
 * cumulative summary when DTrace exits. A CPU that never runs OpenSSL is not
 * emitted by printa(); callers may normalize a missing row to zero.
 */

/* Suppress DTrace's default probe and status messages. */
#pragma D option quiet

/* Reserve additional dynamic-variable memory for the aggregations below. */
#pragma D option dynvarsize=16m

/* Print a heading before scheduler events are collected. */
dtrace:::BEGIN
{
    printf("CPU distribution for openssl\n");
}

/*
 * Count every time an OpenSSL thread starts or resumes execution on a CPU.
 * The cpu built-in variable is used as the aggregation key.
 */
sched:::on-cpu
/execname == "openssl"/
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
