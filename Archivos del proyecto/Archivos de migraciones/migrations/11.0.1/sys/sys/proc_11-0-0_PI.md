# Actualización a FreeBSD v11.0.1

> Se compara el archivo `proc.h` con el mismo archivo de la versión 11.0.0_PI.

```diff
...
		uint64_t	rux_sticks;     /* (cu) Statclock hits in sys mode. */
		uint64_t	rux_iticks;     /* (cu) Statclock hits in intr mode. */
		uint64_t	rux_uu;         /* (c) Previous user time in usec. */
		uint64_t	rux_su;         /* (c) Previous sys time in usec. */
		uint64_t	rux_tu;         /* (c) Previous total time in usec. */
	};

+	/* DEFINITIONS OF TRANSITIONS AND PLACES FOR THREAD NET*/
+	#define PLACE_INACTIVE 0
+	#define PLACE_CAN_RUN 1
+	#define PLACE_CPU_RUN_QUEUE 2
+	#define PLACE_RUNNING 3
+	#define PLACE_INHIBITED 4
+
+	#define TRAN_INIT 0
+	#define TRAN_ON_QUEUE 1
+	#define TRAN_SET_RUNNING 2
+	#define TRAN_SWITCH_OUT 3
+	#define TRAN_TO_WAIT_CHANNEL 4
+	#define TRAN_WAKEUP 5
+	#define TRAN_REMOVE 6
+
+	#define PLACES_SIZE 5
+	#define TRANSITIONS_SIZE 7
...
```

```diff
...
	struct vm_domain_policy td_vm_dom_policy;	/* (c) current numa domain policy */
	lwpid_t		td_tid;		/* (b) Thread ID. */
+	int 	td_frominh;		/* Thread comes from an inhibited state*/
	sigqueue_t	td_sigqueue;	/* (c) Sigs arrived, not delivered. */

...

```

```diff
...
	const char	*td_vnet_lpush;	/* (k) Debugging vnet push / pop. */
	struct trapframe *td_intr_frame;/* (k) Frame of the current irq */
	struct proc	*td_rfppwait_p;	/* (k) The vforked child */
	struct vm_page	**td_ma;	/* (k) uio pages held */
	int		td_ma_cnt;	/* (k) size of *td_ma */
	void		*td_emuldata;	/* Emulator state data */
	int		td_lastcpu;	/* (t) Last cpu we were on. */
	int		td_oncpu;	/* (t) Which cpu we are on. */
+	int mark[PLACES_SIZE];
+	int sensitized_buffer[TRANSITIONS_SIZE];
	};
...
```
