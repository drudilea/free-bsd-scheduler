#!/usr/sbin/dtrace -s

/*
 * Detect ordinary user threads entering a CPU reserved for a specific TID.
 *
 * Usage:
 *   dtrace -s reserved_cpu_foreign_threads.d <reserved_cpu> <reserved_tid>
 *
 * Arguments:
 *   $1 - CPU ID that should be reserved.
 *   $2 - TID that owns the reservation.
 *
 * Scope: pid > 0 and execname != "idle" deliberately exclude kernel-only
 * activity and idle threads. Therefore an empty result supports exclusion of
 * other ordinary user threads, not absolute hardware-level CPU isolation.
 */

/* Suppress DTrace's default probe and status messages. */
#pragma D option quiet

/* Reserve additional dynamic-variable memory for keyed aggregations. */
#pragma D option dynvarsize=16m

/* Echo the selected CPU and owner TID at the start of the measurement. */
dtrace:::BEGIN
{
    printf("Foreign user threads on cpu %d while tid %d is reserved\n", $1, $2);
}

/*
 * Match on-cpu events on the reserved CPU, excluding:
 *   - the TID that owns the reservation;
 *   - pid 0 kernel activity;
 *   - idle threads.
 */
sched:::on-cpu
/cpu == $1 && tid != $2 && pid > 0 && execname != "idle"/
{
    /* Group foreign events by executable name. */
    @by_exec[execname] = count();

    /* Group the same events by thread ID. */
    @by_tid[tid] = count();

    /* Count all matching foreign user-thread entries. */
    @total = count();
}

/* Print cumulative progress snapshots every five seconds. */
tick-5s
{
    printf("\nPartial summary by execname\n");
    printa("exec,%s,%@d\n", @by_exec);
    printf("Partial summary by tid\n");
    printa("tid,%d,%@d\n", @by_tid);
    printa("total,%@d\n", @total);
}

/* Print the final cumulative aggregations when DTrace exits. */
dtrace:::END
{
    printf("\nFinal summary by execname\n");
    printa("exec,%s,%@d\n", @by_exec);
    printf("Final summary by tid\n");
    printa("tid,%d,%@d\n", @by_tid);
    printa("total,%@d\n", @total);
}
