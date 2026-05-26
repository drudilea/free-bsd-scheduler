#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
    secs = 0;
    cs = 0;
    printf("second,tid_context_switches\n");
}

sched:::off-cpu
/tid == $1/
{
    cs++;
}

tick-1s
{
    secs++;
    printf("%d,%d\n", secs, cs);
    cs = 0;
}
