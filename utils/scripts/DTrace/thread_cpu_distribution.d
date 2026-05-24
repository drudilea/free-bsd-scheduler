#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option dynvarsize=16m

dtrace:::BEGIN
{
    printf("CPU distribution for tid %d\n", $1);
}

sched:::on-cpu
/tid == $1/
{
    @by_cpu[cpu] = count();
    @total = count();
}

tick-5s
{
    printf("\nPartial summary\n");
    printa("cpu,%d,%@d\n", @by_cpu);
    printa("total,%@d\n", @total);
}

dtrace:::END
{
    printf("\nFinal summary\n");
    printa("cpu,%d,%@d\n", @by_cpu);
    printa("total,%@d\n", @total);
}
