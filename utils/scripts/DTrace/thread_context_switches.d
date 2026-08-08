#!/usr/sbin/dtrace -s

/*
 * Count how often one selected thread leaves a CPU in each one-second window.
 *
 * Usage:
 *   dtrace -s thread_context_switches.d <tid>
 *
 * Argument:
 *   $1 - TID to observe.
 *
 * An off-cpu event is a limited approximation of a context switch for the
 * selected thread. The script does not classify voluntary versus involuntary
 * exits and does not count context switches from unrelated threads.
 */

/* Suppress DTrace's default probe and status messages. */
#pragma D option quiet

/* Initialize the elapsed-second and per-window event counters. */
dtrace:::BEGIN
{
    secs = 0;
    cs = 0;
    printf("second,tid_context_switches\n");
}

/* Count off-cpu events only for the TID supplied as the first argument. */
sched:::off-cpu
/tid == $1/
{
    cs++;
}

/* Print the current one-second bucket and reset it for the next interval. */
tick-1s
{
    secs++;
    printf("%d,%d\n", secs, cs);
    cs = 0;
}
