# Modelado del planificador a corto plazo con redes de Petri (resúmen)

## Modelado del hilo

<img src="../../assets/thread_model.jpeg" width="500px">

- **T0**: El paso del estado INACTIVE a CAN RUN. Esto sucede cuando el hilo se agrega al scheduler. Esto sucede generalmente en momento de creación de un proceso o cuando el mismo realiza un fork. Esta tarea no corresponde al scheduler, por lo que inicialmente un hilo en el scheduler se encuentra inicializado en el estado CAN RUN. Esta transición nunca se dispara, solo se la incorpora al modelo de modo representativo.
- **T1**: El hilo se pone en una cola local de una determinada CPU o en la cola global dependiendo de la disponibilidad. Esta cola organiza los hilos de acuerdo a sus prioridades de ejecución.
- **T2**: El hilo se quita de la cola y pasa a ejecutar las instrucciones del programa que tiene asignadas. En este instante el procesador se encuentra ocupado por dicho hilo.
- **T3**: El scheduler interrumpe el hilo y lo vuelve a colocar en una cola. El planificador toma otro hilo de la cola (el de mayor prioridad) y realiza un cambio de contexto.
- **T4**: Algún evento, semáforo o espera bloquea al hilo. Se agrega en una sleepq o turnstile, en la cual el hilo queda a la espera de un evento que le quitará el bloqueo.
- **T5**: Se desbloquea el hilo y puede volver a encolarse nuevamente. El evento que lo desbloquea se genera fuera del scheduler. El hilo queda a la espera para poder cambiar de estado cuando corresponda.

### Archivo [`proc.h`](../../migrations/11.0.0_PI/sys/sys/proc.h)

- `mark`: vector que tiene el marcado inicial, con tamaño `PLACES_SIZE`.
- `sensitized_buffer`: vector que representa las transiciones sensibilizadas de su red asociada, con tamaño `TRANSITIONS_SIZE`.

<details><summary><b style="cursor: pointer;">Ver código</b></summary>

```h
...
#define PLACES_SIZE 5
#define TRANSITIONS_SIZE 7
...

struct thread {
	struct mtx	*volatile td_lock; /* replaces sched lock */
	struct proc	*td_proc;	/* (*) Associated process. */
	TAILQ_ENTRY(thread) td_plist;	/* (*) All threads in this proc. */
	TAILQ_ENTRY(thread) td_runq;	/* (t) Run queue. */
    ...
	int mark[PLACES_SIZE];
	int sensitized_buffer[TRANSITIONS_SIZE];
};
```

</details>

---

### Archivo [`sched_petri.h`](../../migrations/11.0.0_PI/sys/sys/sched_petri.h)

- `init_petri_thread`: esta función recibe un thread como parámetro y procede a inicializar su `mark` al marcado inicial.
- `thread_get_sensitized`: recibe un thread como parámetro y analiza todas sus transiciones para actualizar su `sensitized_buffer` (función no utilizada).
- `thread_petri_fire`: recibe un thread y una transición como parámetros y la dispara haciendo uso de la matriz de incidencia, actualizando finalmente su marcado.
- `thread_search_and_fire`: recibe un thread como parámetro y calcula sus transiciones sensibilizadas para proceder a dispararlas (función no utilizada).

<details><summary><b style="cursor: pointer;">Ver código</b></summary>

```h
#ifndef SCHED_PETRI_H
#define SCHED_PETRI_H
...
#include <sys/proc.h>
...

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

...
#endif
```

</details>

---

### Archivo [`sched_petri.c`](../../migrations/11.0.0_PI/sys/kern/sched_petri.c)

Se declara la matriz de incidencia (`matrix_Incidence`) y el vector de marcado inicial (`initial_mark`), y a su vez se implementan las funciones declaradas en `sched_petri.h`

<details><summary><b style="cursor: pointer;">Ver código</b></summary>

```c
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
...
```

</details>

---

### Archivo [`kern_thread.c`](../../migrations/11.0.0_PI/sys/kern/kern_thread.c)

Llamar a `init_petri_net(td)` para inicializar y asignar memoria para la red.

<details><summary><b style="cursor: pointer;">Ver código</b></summary>

```c
...

/*
 * Allocate a thread.
 */
struct thread *
thread_alloc(int pages)
{
	struct thread *td;

	thread_reap(); /* check if any zombies to get */

	td = (struct thread *)uma_zalloc(thread_zone, M_WAITOK);
	KASSERT(td->td_kstack == 0, ("thread_alloc got thread with kstack"));
	if (!vm_thread_new(td, pages)) {
		uma_zfree(thread_zone, td);
		return (NULL);
	}
	cpu_thread_alloc(td);
	vm_domain_policy_init(&td->td_vm_dom_policy);
	init_petri_thread(td);
	return (td);
}

...
```

<details><summary><b style="cursor: pointer;">Ver código</b></summary>

---

## Bibliografía

[Repositorio Nicolas Papp][nicolaspapp repo]

<!-- Global variables -->

[nicolaspapp repo]: https://github.com/nicolaspapp/freebsd/tree/final-project
