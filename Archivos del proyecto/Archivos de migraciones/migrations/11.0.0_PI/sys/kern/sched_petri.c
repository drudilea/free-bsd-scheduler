#include <sys/sched_petri.h>

/*
GLOBAL VARIABLES
*/
const int matrix_Incidence[PLACES_SIZE][TRANSITIONS_SIZE] = {
	{-1,  0,  0,  0,  0,  0 ,  0},
	{ 1, -1,  0,  1,  0,  1 ,  1},
	{ 0,  1, -1,  0,  0,  0 , -1},
	{ 0,  0,  1, -1, -1,  0 ,  0},
	{ 0,  0,  0,  0,  1, -1 ,  0}
};

const int initial_mark[PLACES_SIZE] = { 0, 1, 0, 0, 0 };

__inline int
thread_transition_is_sensitized(struct thread *pt, int transition_index);


void
init_petri_thread(struct thread *pt_thread){
	// Create a new petr_thread structure
	int i;
	for (i = 0; i < PLACES_SIZE; i++) {
		pt_thread->mark[i] = initial_mark[i];
	}
	pt_thread->td_frominh = 0;
}

void
thread_get_sensitized(struct thread *pt)
{
	int k;
	for(k=0; k< TRANSITIONS_SIZE; k++){
		if(thread_transition_is_sensitized(pt, k))
			pt->sensitized_buffer[k] = 1;
		else
			pt->sensitized_buffer[k] = 0;
	}
};

__inline int
thread_transition_is_sensitized(struct thread *pt, int transition_index)
{
	int places_index;

	for (places_index = 0; places_index < PLACES_SIZE; places_index++) {

		if (((matrix_Incidence[places_index][transition_index] < 0) && 
			//If incidence is positive we really dont care if there are tokens or not
			((matrix_Incidence[places_index][transition_index] + pt->mark[places_index]) < 0)))
		{
			return 0;
		}
	}

	return 1;

}

void
thread_petri_fire(struct thread *pt, int transition)
{
	int i;
	if(thread_transition_is_sensitized(pt, transition)){
		for(i=0; i< PLACES_SIZE; i++)
			pt->mark[i] += matrix_Incidence[i][transition];
	}
	else
	{
		printf("Transition %2d no estaba sensibilizada para thread %d\n", transition, pt->td_tid);
		thread_print_net(pt);
		print_resource_net();	
	}
}


/*This method is not used yet */
static void
thread_search_and_fire(struct thread *pt){
	int i;
	thread_get_sensitized(pt);
	i=0;
	while((pt->sensitized_buffer[i] != 1) && (i < TRANSITIONS_SIZE)){
		i++;
	}
	if(i < TRANSITIONS_SIZE){
		thread_petri_fire(pt, i);
	}
}

void thread_print_net(struct thread *pt)
{
	int i;
	printf("Marcado thread %d: ", pt->td_tid);
	for(i=0; i< PLACES_SIZE; i++){
		printf("%d ", pt->mark[i]);
	}
	printf("\n");
}