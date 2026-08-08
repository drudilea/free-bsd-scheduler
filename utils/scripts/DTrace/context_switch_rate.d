#!/usr/sbin/dtrace -s

/*
 * Count how often OpenSSL threads leave a CPU during each one-second window.
 *
 * An off-cpu event is used here as a limited approximation of a context
 * switch for the observed workload. It is not a system-wide context-switch
 * counter and does not distinguish between voluntary and involuntary exits.
 *
 * Usage:
 *   dtrace -s context_switch_rate.d
 *
 * Output format:
 *   second,total_context_switches
 */

/* Suppress DTrace's default probe and status messages. */
#pragma D option quiet

/* Initialize the elapsed-second and per-window event counters. */
dtrace:::BEGIN
{
    secs = 0;
    cs = 0;
    printf("second,total_context_switches\n");
}

/*
 * Fire whenever a thread leaves a CPU, but count only events whose executable
 * name is "openssl". Other processes and kernel threads are ignored.
 */
sched:::off-cpu
/execname == "openssl"/
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
