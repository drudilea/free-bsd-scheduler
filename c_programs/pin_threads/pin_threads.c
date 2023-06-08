// clang-format off
#include <sys/param.h>
#include <sys/module.h>
#include <sys/systm.h>
#include <sys/kernel.h>
#include <sys/sched_petri.h>
// clang-format on

/* The function called at load/unload. */
static int event_handler(struct module *module, int event, void *arg)
{
  int e = 0; /* Error, 0 for normal return status */
  switch (event)
  {
  case MOD_LOAD:
    uprintf("Hello chicos tesis! \n");
    toggle_pin_thread_to_cpu(100420, 2);
    set_print_transition(1000);
    break;
  case MOD_UNLOAD:
    toggle_pin_thread_to_cpu(100420, 2);
    uprintf("Bye Bye chicos tesis !\n");
    break;
  default:
    e = EOPNOTSUPP; /* Error, Operation Not Supported */
    break;
  }

  return (e);
}

/* The second argument of DECLARE_MODULE. */
static moduledata_t pin_thread_to_cpu_conf = {
    "pin_thread_to_cpu", /* module name */
    event_handler,       /* event handler */
    NULL                 /* extra data */
};
/* TODO: Test SI_SUB_EXEC as third argument */
DECLARE_MODULE(pin_thread_to_cpu, pin_thread_to_cpu_conf, SI_SUB_DRIVERS,
               SI_ORDER_MIDDLE);
