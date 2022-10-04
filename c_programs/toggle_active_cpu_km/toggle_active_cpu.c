// clang-format off
#include <sys/param.h>
#include <sys/module.h>
#include <sys/systm.h>
#include <sys/kernel.h>
#include <sys/sched_petri.h>
// clang-format on

/* The function called at load/unload. */
static int event_handler(struct module *module, int event, void *arg) {
  int e = 0; /* Error, 0 for normal return status */
  switch (event) {
  case MOD_LOAD:
    uprintf("Hello chicos tesis! \n");
    toggle_active_cpu(0);
    set_print_transition(1000);
    break;
  case MOD_UNLOAD:
    uprintf("Bye Bye chicos tesis !\n");
    break;
  default:
    e = EOPNOTSUPP; /* Error, Operation Not Supported */
    break;
  }

  return (e);
}

/* The second argument of DECLARE_MODULE. */
static moduledata_t toggle_active_cpu_conf = {
    "toggle_active_cpu", /* module name */
    event_handler,       /* event handler */
    NULL                 /* extra data */
};
/* TODO: Test SI_SUB_EXEC as third argument */
DECLARE_MODULE(toggle_active_cpu, toggle_active_cpu_conf, SI_SUB_DRIVERS,
               SI_ORDER_MIDDLE);
