#!/usr/sbin/dtrace -s

/*
 * Summarize enqueue decisions and fired transitions from the Petri scheduler.
 *
 * Requirements:
 *   - a kernel that exposes the custom SDT provider named "petri";
 *   - DTrace kernel modules loaded, for example with kldload dtraceall.
 *
 * Usage:
 *   kldload dtraceall
 *   dtrace -l -P petri
 *   dtrace -s utils/scripts/DTrace/petri_addtoqueue.d
 *
 * Run the workload in another terminal and stop this script with Ctrl-C. The
 * script prints a cumulative summary when it receives the interrupt.
 *
 * Scope and limitations:
 *   - counts represent probe events observed during one tracing window;
 *   - percentages describe enqueue paths, not workload performance;
 *   - BLOCKED_TRANSITIONS = 0 applies only to the observed window and is not
 *     proof that a blocked transition can never occur.
 */

/* Suppress DTrace's default probe and status messages. */
#pragma D option quiet

/* Reserve additional dynamic-variable memory for keyed aggregations. */
#pragma D option dynvarsize=16m

/* Initialize scalar counters and print a heading before tracing begins. */
dtrace:::BEGIN
{
	policy_decisions = 0;
	forced_decisions = 0;
	forced_pinned = 0;
	forced_bound = 0;
	forced_affinity_fallback = 0;
	global_decisions = 0;
	policy_fired = 0;
	forced_fired = 0;
	blocked_total = 0;

	printf("Tracing Petri addtoqueue probes. Press Ctrl-C to summarize.\n");
}

/*
 * Observe the path selected by sched_add() for a thread enqueue operation.
 *
 * Probe arguments:
 *   args[0] - thread being enqueued;
 *   args[1] - target CPU;
 *   args[2] - local Petri transition (normal or forced ADDTOQUEUE);
 *   args[3] - decision reason: 0 policy, 1 pinned, 2 bound,
 *             3 affinity fallback;
 *   args[4] - scheduler enqueue flags.
 */
petri:sched:addtoqueue:decision
{
	/* Group decisions by reason, target CPU, and selected transition. */
	@decisions[
	    args[3] == 1 ? "pinned" :
	    args[3] == 2 ? "bound" :
	    args[3] == 3 ? "affinity-fallback" : "policy",
	    args[1],
	    args[2]] = count();

	/* Maintain totals used by the compact final summary. */
	policy_decisions += args[3] == 0 ? 1 : 0;
	forced_decisions += args[3] != 0 ? 1 : 0;
	forced_pinned += args[3] == 1 ? 1 : 0;
	forced_bound += args[3] == 2 ? 1 : 0;
	forced_affinity_fallback += args[3] == 3 ? 1 : 0;
}

/*
 * Count enqueues sent to the global run queue instead of a per-CPU queue.
 * args[1] contains scheduler flags and args[2] reports whether SMP started.
 */
petri:sched:addtoqueue:global
{
	@global[args[2] ? "smp-started" : "smp-not-started"] = count();
	global_decisions++;
}

/*
 * Observe a normal ADDTOQUEUE transition after it successfully fires.
 * args[2] is the target CPU; args[3] and args[4] are the resulting QUEUE and
 * CANTQ place markings for that CPU.
 */
petri:resource:addtoqueue:policy
{
	/* Preserve both the fired count and the resulting Petri-net markings. */
	@fired["policy", args[2]] = count();
	@queue_after["policy", args[2], args[3]] = count();
	@cantq_after["policy", args[2], args[4]] = count();

	policy_fired++;
}

/*
 * Observe a forced ADDTOQUEUE transition after it successfully fires. Its
 * arguments have the same CPU and post-fire marking layout as the policy
 * probe above.
 */
petri:resource:addtoqueue:forced
{
	/* Preserve both the fired count and the resulting Petri-net markings. */
	@fired["forced", args[2]] = count();
	@queue_after["forced", args[2], args[3]] = count();
	@cantq_after["forced", args[2], args[4]] = count();

	forced_fired++;
}

/*
 * Record attempts to fire a resource transition that was not sensitized.
 * args[2] is the global transition index, args[3] its target CPU, and args[4]
 * the CPU running the code that attempted to fire it.
 */
petri:resource:transition:blocked
{
	@blocked[args[2], args[3], args[4]] = count();
	blocked_total++;
}

/* Print decision totals and percentages when at least one decision exists. */
dtrace:::END
/(policy_decisions + forced_decisions + global_decisions) > 0/
{
	this->total = policy_decisions + forced_decisions + global_decisions;

	printf("\nPetri sched_add decision totals:\n");
	printf("%24s %12s %10s\n", "kind", "count", "percent");
	printf("%24s %12d %7d.%02d%%\n", "QUEUE_GLOBAL",
	    global_decisions, (global_decisions * 100) / this->total,
	    ((global_decisions * 10000) / this->total) % 100);
	printf("%24s %12d %7d.%02d%%\n", "ADDTOQUEUE_POLICY",
	    policy_decisions, (policy_decisions * 100) / this->total,
	    ((policy_decisions * 10000) / this->total) % 100);
	printf("%24s %12d %7d.%02d%%\n", "ADDTOQUEUE_FORCED",
	    forced_decisions, (forced_decisions * 100) / this->total,
	    ((forced_decisions * 10000) / this->total) % 100);
	printf("%24s %12d %7s\n", "TOTAL", this->total, "100.00%");
}

/* Produce an explicit message instead of an empty table when nothing fired. */
dtrace:::END
/(policy_decisions + forced_decisions + global_decisions) == 0/
{
	printf("\nPetri sched_add decision totals:\n");
	printf("No sched_add enqueue decisions captured.\n");
}

/* Break forced decisions down by the kernel constraint that caused them. */
dtrace:::END
/forced_decisions > 0/
{
	printf("\nPetri forced decision breakdown:\n");
	printf("%24s %12s %18s\n", "reason", "count", "percent_of_forced");
	printf("%24s %12d %15d.%02d%%\n", "pinned",
	    forced_pinned, (forced_pinned * 100) / forced_decisions,
	    ((forced_pinned * 10000) / forced_decisions) % 100);
	printf("%24s %12d %15d.%02d%%\n", "bound",
	    forced_bound, (forced_bound * 100) / forced_decisions,
	    ((forced_bound * 10000) / forced_decisions) % 100);
	printf("%24s %12d %15d.%02d%%\n", "affinity-fallback",
	    forced_affinity_fallback,
	    (forced_affinity_fallback * 100) / forced_decisions,
	    ((forced_affinity_fallback * 10000) / forced_decisions) % 100);
}

/*
 * Compare policy and forced transitions that actually fired, and report how
 * many non-sensitized transition attempts were observed in the same window.
 */
dtrace:::END
/(policy_fired + forced_fired) > 0/
{
	this->total = policy_fired + forced_fired;

	printf("\nPetri addtoqueue fired totals:\n");
	printf("%24s %12s %10s\n", "kind", "count", "percent");
	printf("%24s %12d %7d.%02d%%\n", "ADDTOQUEUE_POLICY",
	    policy_fired, (policy_fired * 100) / this->total,
	    ((policy_fired * 10000) / this->total) % 100);
	printf("%24s %12d %7d.%02d%%\n", "ADDTOQUEUE_FORCED",
	    forced_fired, (forced_fired * 100) / this->total,
	    ((forced_fired * 10000) / this->total) % 100);
	printf("%24s %12d %7s\n", "TOTAL", this->total, "100.00%");
	printf("%24s %12d\n", "BLOCKED_TRANSITIONS", blocked_total);
}

/* Print detailed cumulative aggregations after the compact summary tables. */
dtrace:::END
{
	printf("\nPetri sched_add decisions by reason, target CPU and transition:\n");
	printa("%20s cpu=%d transition=%d %@d\n", @decisions);

	printf("\nPetri global queue enqueues:\n");
	printa("%20s %@d\n", @global);

	printf("\nPetri addtoqueue transitions fired by kind and CPU:\n");
	printa("%20s cpu=%d %@d\n", @fired);

	printf("\nPetri queue mark after addtoqueue by kind, CPU and mark:\n");
	printa("%20s cpu=%d queue_mark=%d %@d\n", @queue_after);

	printf("\nPetri CANTQ mark after addtoqueue by kind, CPU and mark:\n");
	printa("%20s cpu=%d cantq_mark=%d %@d\n", @cantq_after);

	printf("\nBlocked Petri transitions by transition, target CPU and running CPU:\n");
	printa("transition=%d target_cpu=%d running_cpu=%d %@d\n", @blocked);
}
