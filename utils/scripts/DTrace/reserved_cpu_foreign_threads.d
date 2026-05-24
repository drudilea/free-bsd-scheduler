#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option dynvarsize=16m

dtrace:::BEGIN
{
    printf("Foreign user threads on cpu %d while tid %d is reserved\n", $1, $2);
}

sched:::on-cpu
/cpu == $1 && tid != $2 && pid > 0 && execname != "idle"/
{
    @by_exec[execname] = count();
    @by_tid[tid] = count();
    @total = count();
}

tick-5s
{
    printf("\nPartial summary by execname\n");
    printa("exec,%s,%@d\n", @by_exec);
    printf("Partial summary by tid\n");
    printa("tid,%d,%@d\n", @by_tid);
    printa("total,%@d\n", @total);
}

dtrace:::END
{
    printf("\nFinal summary by execname\n");
    printa("exec,%s,%@d\n", @by_exec);
    printf("Final summary by tid\n");
    printa("tid,%d,%@d\n", @by_tid);
    printa("total,%@d\n", @total);
}
