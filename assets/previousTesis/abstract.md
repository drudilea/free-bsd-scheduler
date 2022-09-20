# Modelado del planificador a corto plazo con redes de Petri (resúmen)

## Modelado del hilo

<img src="../../assets/thread_model.jpeg" width="400px">

- **T0**: El paso del estado INACTIVE a CAN RUN. Esto sucede cuando el hilo se agrega al scheduler. Esto sucede generalmente en momento de creación de un proceso o cuando el mismo realiza un fork. Esta tarea no corresponde al scheduler, por lo que inicialmente un hilo en el scheduler se encuentra inicializado en el estado CAN RUN. Esta transición nunca se dispara, solo se la incorpora al modelo de modo representativo.
- **T1**: El hilo se pone en una cola local de una determinada CPU o en la cola global dependiendo de la disponibilidad. Esta cola organiza los hilos de acuerdo a sus prioridades de ejecución.
- **T2**: El hilo se quita de la cola y pasa a ejecutar las instrucciones del programa que tiene asignadas. En este instante el procesador se encuentra ocupado por dicho hilo.
- **T3**: El scheduler interrumpe el hilo y lo vuelve a colocar en una cola. El planificador toma otro hilo de la cola (el de mayor prioridad) y realiza un cambio de contexto.
- **T4**: Algún evento, semáforo o espera bloquea al hilo. Se agrega en una sleepq o turnstile, en la cual el hilo queda a la espera de un evento que le quitará el bloqueo.
- **T5**: Se desbloquea el hilo y puede volver a encolarse nuevamente. El evento que lo desbloquea se genera fuera del scheduler. El hilo queda a la espera para poder cambiar de estado cuando corresponda.

### Correspondencia entre el nombre de las plazas del modelo con el nombre de las plazas en el código

| Modelo    | Código              |
| --------- | ------------------- |
| Inactive  | PLACE_INACTIVE      |
| Can_run   | PLACE_CAN_RUN       |
| Runq      | PLACE_CPU_RUN_QUEUE |
| Runninr   | PLACE_RUNNING       |
| Inhibited | PLACE_INHIBITED     |

---

### Archivos de interés

- Archivo [`proc.h`](../../migrations/11.0.0_PI/sys/sys/proc.h)

  > `mark`: vector que tiene el marcado inicial, con tamaño `PLACES_SIZE`.
  >
  > `sensitized_buffer`: vector que representa las transiciones sensibilizadas de su red asociada, con tamaño `TRANSITIONS_SIZE`.
  >
  > `td_frominh`: campo que indica cuando un thread acaba de salir de estado inhibido, es decir al retornar de un cambio de contexto voluntario.

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
    int 	td_frominh;		/* Thread comes from an inhibited state*/
  };
  ```

  </details>

<br/>

- Archivo [`sched_petri.h`](../../migrations/11.0.0_PI/sys/sys/sched_petri.h)

  > `init_petri_thread`: esta función recibe un thread como parámetro y procede a inicializar su `mark` al marcado inicial.
  >
  > `thread_get_sensitized`: recibe un thread como parámetro y analiza todas sus transiciones para actualizar su `sensitized_buffer` (función no utilizada).
  >
  > `thread_petri_fire`: recibe un thread y una transición como parámetros y la dispara haciendo uso de la matriz de incidencia, actualizando finalmente su marcado.
  >
  > `thread_search_and_fire`: recibe un thread como parámetro y calcula sus transiciones sensibilizadas para proceder a dispararlas (función no utilizada).

  <details><summary><b style="cursor: pointer;">Ver código</b></summary>

  ```h
  #ifndef SCHED_PETRI_H
  #define SCHED_PETRI_H
  ...
  #include <sys/proc.h>
  ...

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

<br/>

- Archivo [`sched_petri.c`](../../migrations/11.0.0_PI/sys/kern/sched_petri.c)

  > Se declara la matriz de incidencia (`matrix_Incidence`) y el vector de marcado inicial (`initial_mark`), y a su vez se implementan las funciones declaradas en `sched_petri.h`

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

<br/>

- Archivo [`kern_thread.c`](../../migrations/11.0.0_PI/sys/kern/kern_thread.c)

  > Llamar a `init_petri_net(td)` para inicializar y asignar memoria para la red.

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

  </details>

<br/>

---

## Modelado de la red de recursos

<img src="../../assets/single_resource_net_model.png" width="400px">

<details><summary><b style="cursor: pointer;">Ver red de recursos completa</b></summary>
<img src="../../assets/resource_net_model.png">
</details>

---

### Archivos de interés

- Archivo [`sched_petri.h`](../../migrations/11.0.0_PI/sys/sys/sched_petri.h)

  > Se definen las instrucciones que van a representar las plazas y transiciones de la red de recursos
  >
  > Se trabajará con 4 CPUs
  >
  > Se define la estructura `petri_cpu_resource_net` con los siguientes campos:
  >
  > - `mark`: vector que contiene el marcado inicial de la red de recursos, con tamaño `CPU_NUMBER_PLACES`.
  > - `sensitized_buffer`: vector que representa las transiciones sensibilizadas, con tamaño `CPU_NUMBER_TRANSITIONS`.
  > - `cpu_owner_list`: vector con los identificadores de los threads que están utilizando cada CPU, con tamaño `CPU_NUMBER` (campo no utilizado).
  > - `incidence_matrix`: matriz de tamaño `CPU_NUMBER_PLACES` \* `CPU_NUMBER_TRANSITIONS`.
  > - `inhibition_matrix`: matriz de tamaño `CPU_NUMBER_PLACES` \* `CPU_NUMBER_TRANSITIONS`.
  > - `is_automatic_transition`: vector con las transiciones automáticas de la red, de tamaño `CPU_NUMBER_TRANSITIONS`.
  >
  > Se define la función `resource_choose_cpu` que recibe un thread como parámetro y devuelve el índice de la transición de encolado de la CPU que se le asignará a dicho hilo.

  <details><summary><b style="cursor: pointer;">Ver código</b></summary>

  ```h
  #ifndef SCHED_PETRI_H
  #define SCHED_PETRI_H
  ...

  #define CPU_NUMBER 4
  #define CPU_BASE_PLACES 5
  #define CPU_BASE_TRANSITIONS 9
  #define CPU_NUMBER_PLACES (CPU_BASE_PLACES*CPU_NUMBER)+3
  #define CPU_NUMBER_TRANSITION (CPU_BASE_TRANSITIONS*CPU_NUMBER)+4

  /* Definitions of transition and places for the CPU resource net */
  // PLACES
  #define PLACE_CANTQ 0
  #define PLACE_QUEUE 1
  #define PLACE_CPU 2
  #define PLACE_TOEXEC 3
  #define PLACE_EXECUTING 4

  // Global queue independent of the number of CPUs
  #define PLACE_GLOBAL_QUEUE (CPU_NUMBER_PLACES-3)
  #define PLACE_SMP_NOT_READY (CPU_NUMBER_PLACES-2)
  #define PLACE_SMP_READY (CPU_NUMBER_PLACES-1)

  // TRANSITIONS
  #define TRAN_ADDTOQUEUE 0
  #define TRAN_UNQUEUE 1
  #define TRAN_EXEC 2
  #define TRAN_EXEC_EMPTY 3
  #define TRAN_RETURN_VOL 4
  #define TRAN_RETURN_INVOL 5
  #define TRAN_FROM_GLOBAL_CPU 6
  #define TRAN_REMOVE_QUEUE 7
  #define TRAN_REMOVE_EMPTY_QUEUE 8

  // GLOBAL TRANSITIONS
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

  ...

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
  ```

  </details>

  <br/>

- Archivo [`petri_global_net.c`](../../migrations/11.0.0_PI/sys/kern/petri_global_net.c)

  > Se representa la Red de Petri de recursos propuesta junto a su funcionamiento:
  >
  > - `init_resource_net`: función que inicializa `mark`, `incidence_matrix`, `ihibition_matrix` e `is_automatic_transition`.
  >
  > - La transción de descarte `TRAN_THROW` es la única transición automática de la red. Una transición automática es aquella que se dispara cada vez que se encuentra sensibilizada.
  >
  > - `resource_get_sensitized`: analiza todas sus transiciones para actualizar su `sensitized_buffer` (funcíon no utilizada).
  >
  > - `resource_fire_net`: recibe un thread y un índice de transición como parámetros, dispara la transición en la red global haciendo uso de la matriz de incidencia y dispara las transiciones automáticas que se habiliten.
  >
  > - `hierarchical_transitions`: vector con las transiciones jerárquicas de la red de recursos. Ordenadas de acuerdo al índice correspondiente con `hierarchical_corresponse`.
  >
  > - `hierarchical_corresponse`: vector con las transiciones jerárquicas de la red del thread. Ordenadas de acuerdo al índice correspondiente con `hierarchical_transitions`.
  >
  > - Se llama a `resource_fire_net` en sched_choose para contemplar el desencolado de los threads que van a pasar a ejecución en la CPU que le corresponda.
  >
  > Se implementa la función `resource_expulse_thread` que recibe un hilo como parámetro. Devuelve el índice de transición de retorno voluntario o involuntario y cambia el valor de la variable `td_frominh` según corresponda.

  <br/>

- Archivo [`sched_4bsd.c`](../../migrations/11.0.0_PI/sys/kern/sched_4bsd.c)

  > En la función `sched_setup`, dónde se inicializa el scheduler, se llama a `init_resource_net` para inicializar y asignar espacio de memoria para la red de recursos.
  >
  > En la función `sched_add` se llama a `resource_fire_net` para contemplar en la red el encolado de los threads que ingresan al scheduler en la CPU que le corresponda.
  >
  > Cuando finaliza la ejecución de los threads, ya sea de forma voluntaria o no, se llama a `resource_expulse_thread` para liberar la CPU en el código fuente dentro de la función `sched_switch`.
  >
  > En la función `sched_switch` se llama a `resource_fire_net` para contemplar en la red el desencolado de los threads que van a pasar a ejecución en la CPU que le corresponda o en la cola global en caso de no tener afinidad. Una vez que se desencola un thread, se llama a `resource_execute_thread` para ejecutar la transición de ejecución que corresponda, según el valor de `smp_set`.
  >
  > En la función `sched_choose` se busca el próximo hilo a correr. En monoprocesador lo obtiene de la cola global. Mientras que en SMP busca un hilo en la cola global y otro en el CPU que está ejecutando actualmente. En caso de que encuentre hilos en ambas colas, selecciona el de mayor prioridad.
  > Luego de disparar la transición de desencolado correspondiente, remueve el hilo de la cola y devuelve el mismo.
  > Solo en el caso de que no haya hilos en ninguna cola, se utiliza el mecanismo del `idlethread` para ejecutar un hilo vacío.

    <details><summary><b style="cursor: pointer;">Ver código</b></summary>

  ```c
  ...

  /* ARGSUSED */
  static void
  sched_setup(void *dummy)
  {

    setup_runqs();
    init_resource_net();
    /* Account for thread0. */
    sched_load_add();
  }

  ...

  ...

  // sched_add() - Sacar el thread del estado inhibido
  if (td && ((td)->td_frominh == 1))
  {
  	thread_petri_fire(td, TRAN_WAKEUP);
  	td->td_frominh = 0;
  }
  ...

  // sched_add() - Encolado de threads con afinidad o cola global
  cpu = sched_pickcpu(td);
  if (cpu != NOCPU)
  {
    ts->ts_runq = &runq_pcpu[cpu];
    single_cpu = 1;
    resource_fire_net(td, TRAN_ADDTOQUEUE + (cpu * CPU_BASE_TRANSITIONS));
  }
  else
  {
    ts->ts_runq = &runq;
    resource_fire_net(td, TRAN_QUEUE_GLOBAL);
  }

  ...

  ...
  // sched_switch() - Liberar CPU asociada al thread
  resource_expulse_thread(td, flags);

  ...
  // sched_switch() - Threads que pasan a ejecución en la CPU que corresponda
  if (ts->ts_runq != &runq)
  {
    resource_fire_net(newtd, TRAN_UNQUEUE + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
  }
  else
  {
    resource_fire_net(newtd, TRAN_FROM_GLOBAL_CPU + (PCPU_GET(cpuid) * CPU_BASE_TRANSITIONS));
  }
  ...

  // sched_pickcpu() - Llama a resource_choose_cpu para elegir la CPU que le corresponde al thread
  static int sched_pickcpu(struct thread *td)
  {
    int transition, cpu;

    mtx_assert(&sched_lock, MA_OWNED);

    transition = resource_choose_cpu(td);

    if (transition == TRAN_QUEUE_GLOBAL)
      cpu = -1;
    else
      cpu = (int)(transition / CPU_BASE_TRANSITIONS);

    return (cpu);
  }
  ```

    </details>

  <br/>

### Correspondencia entre el nombre de las transiciones y su respectivo índice con el numero final de transición en el código (por procesador/global)

| Código                   | index PROC0 | index PROC1 | index PROC2 | index PROC3 | index GLOBAL |
| ------------------------ | :---------: | :---------: | :---------: | :---------: | :----------: |
| TRAN_ADDTOQUEUE          |      0      |      9      |     18      |     27      |              |
| TRAN_UNQUEUE             |      1      |     10      |     19      |     28      |              |
| TRAN_EXEC                |      2      |     11      |     20      |     29      |              |
| TRAN_EXEC_EMPTY          |      3      |     12      |     21      |     30      |              |
| TRAN_RETURN_VOL          |      4      |     13      |     22      |     31      |              |
| TRAN_RETURN_INVOL        |      5      |     14      |     23      |     32      |              |
| TRAN_FROM_GLOBAL_CPU     |      6      |     15      |     24      |     33      |              |
| TRAN_REMOVE_QUEUE        |      7      |     16      |     25      |     34      |              |
| TRAN_REMOVE_EMPTY_QUEUE  |      8      |     17      |     26      |     35      |              |
| TRAN_REMOVE_GLOBAL_QUEUE |             |             |             |             |      36      |
| TRAN_START_SMP           |             |             |             |             |      37      |
| TRAN_THROW               |             |             |             |             |      38      |
| TRAN_QUEUE_GLOBAL        |             |             |             |             |      39      |

<br/>

---

## Bibliografía

[Repositorio Nicolas Papp][nicolaspapp repo]

<!-- Global variables -->

[nicolaspapp repo]: https://github.com/nicolaspapp/freebsd/tree/final-project
