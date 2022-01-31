#include <sys/param.h>
#include <sys/module.h>
#include <sys/kernel.h>
#include <sys/systm.h>

void hello_debug_unload(void);
void hello_debug_unload(void) /* needed for testing remote debugging */
{
    uprintf("Bye Bye hello_debug_unload\n");
}

/* The function called at load/unload. */
static int event_handler(struct module *module, int event, void *arg)
{
    int e = 0; /* Error, 0 for normal return status */
    switch (event)
    {
    case MOD_LOAD:
        uprintf("Hello chicos tesis! \n");
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
static moduledata_t hello_conf = {
    "hello",       /* module name */
    event_handler, /* event handler */
    NULL           /* extra data */
};
DECLARE_MODULE(hello, hello_conf, SI_SUB_DRIVERS, SI_ORDER_MIDDLE);
