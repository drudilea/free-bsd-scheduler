#ifndef SCHED_PETRI_H
#define SCHED_PETRI_H

#include <sys/param.h>
#include <sys/proc.h>

#define CPU_NUMBER 4
// FOR GLOBAL TRANISTIONS
#define CPU_BASE_PLACES 5
#define CPU_BASE_TRANSITIONS 9
#define CPU_NUMBER_PLACES (CPU_BASE_PLACES*CPU_NUMBER)+3
#define CPU_NUMBER_TRANSITION (CPU_BASE_TRANSITIONS*CPU_NUMBER)+4
/* Definitions of transition and places for the CPU resource net */
//PLACES
#define PLACE_CANTQ 0
#define PLACE_QUEUE 1
#define PLACE_CPU 2
#define PLACE_TOEXEC 3
#define PLACE_EXECUTING 4


// Global queue independent of the number of CPUs
#define PLACE_GLOBAL_QUEUE (CPU_NUMBER_PLACES-3)
#define PLACE_SMP_NOT_READY (CPU_NUMBER_PLACES-2)
#define PLACE_SMP_READY (CPU_NUMBER_PLACES-1)

//TRANSITION
#define TRAN_ADDTOQUEUE 0
#define TRAN_UNQUEUE 1
#define TRAN_EXEC 2
#define TRAN_EXEC_EMPTY 3
#define TRAN_RETURN_VOL 4
#define TRAN_RETURN_INVOL 5
#define TRAN_FROM_GLOBAL_CPU 6
#define TRAN_REMOVE_QUEUE 7
#define TRAN_REMOVE_EMPTY_QUEUE 8


//Global transition
#define TRAN_REMOVE_GLOBAL_QUEUE (CPU_NUMBER_TRANSITION-4) 
#define TRAN_START_SMP (CPU_NUMBER_TRANSITION-3)
#define TRAN_THROW (CPU_NUMBER_TRANSITION-2)
#define TRAN_QUEUE_GLOBAL (CPU_NUMBER_TRANSITION-1)

struct petri_cpu_resource_net {
	int mark[CPU_NUMBER_PLACES];
	int sensitized_buffer[CPU_NUMBER_TRANSITION];
	int cpu_owner_list[CPU_NUMBER];
	char incidence_matrix[CPU_NUMBER_PLACES][CPU_NUMBER_TRANSITION];
	char inhibition_matrix[CPU_NUMBER_PLACES][CPU_NUMBER_TRANSITION];
	int is_automatic_transition[CPU_NUMBER_TRANSITION];
};

//Petri thread Methods
void init_petri_thread(struct thread *pt_thread);
void thread_get_sensitized(struct thread *pt);
__inline int thread_transition_is_sensitized(struct thread *pt, int transition_index);
void thread_petri_fire(struct thread *pt, int transition);
void thread_print_net(struct thread *pt);

//Petri Global Methods
void init_resource_net(void);
void resource_get_sensitized(void);
void resource_fire_net(struct thread *pt, int transition_index);
int resource_choose_cpu(struct thread *td);
void resource_expulse_thread(struct thread *td, int flags);
void resource_execute_thread(struct thread *newtd, int cpu);
void resource_remove_thread(struct thread *newtd, int cpu);
void print_resource_net(void);
void print_uni_label(void);

#endif