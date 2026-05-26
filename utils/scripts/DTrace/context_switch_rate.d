#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
    secs = 0;
    cs = 0;
    printf("second,total_context_switches\n");
}

sched:::off-cpu
/execname == "openssl"/
{
    cs++;
}

tick-1s
{
    secs++;
    printf("%d,%d\n", secs, cs);
    cs = 0;
}

