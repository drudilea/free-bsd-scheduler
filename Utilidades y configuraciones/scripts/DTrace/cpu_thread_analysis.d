#!/usr/sbin/dtrace -s

#pragma D option dynvarsize=2m

sched:::on-cpu
{
    this->cpu = cpu;
}

sched:::off-cpu
/this->cpu != -1/
{
    printf("CPU %d was idle.\n", this->cpu);
    this->cpu = -1;
}

sched:::on-cpu
{
    this->cpu = cpu;
    this->tid = tid;
    this->prio = args[0];
}

sched:::off-cpu
/this->cpu != -1/
{
    printf("CPU %d: Thread ID %d, Priority %d\n", this->cpu, this->tid, this->prio);
    this->cpu = -1;
}