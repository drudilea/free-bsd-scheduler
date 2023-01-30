# Tests

Procedimientos y métodos para verificar que lo implementado en el proyecto final anterior, sigue siendo válido en cualquier versión a la que se quiera migrar.

Para poder desarrollar los procedimientos es necesario conocer la estructura de las redes de petri de los casos sobre los que se ejecutarán las pruebas.

### Modelado de un hilo

<img src="../assets/thread_model.jpeg">

### Modelado de un recurso (CPU)

<img src="../assets/single_resource_net_model.png">

Correspondencia entre el nombre de las plazas del modelo con el nombre de las plazas en el código

| Modelo    | Código          |
| --------- | --------------- |
| Cantq     | PLACE_CANTQ     |
| Queue     | PLACE_QUEUE     |
| CPU       | PLACE_CPU       |
| Toexec    | PLACE_TOEXEC    |
| Executing | PLACE_EXECUTING |

## Invariantes de recursos

- La plaza CPU nunca puede contener mas de dos tokens
- La suma de los tokens de las plazas relacionadas al modelado del CPU no puede ser mayor que uno

## Plazas

| Código              | index PROC0 | index PROC1 | index PROC2 | index PROC3 | index |
| ------------------- | :---------: | :---------: | :---------: | :---------: | :---: |
| PLACE_CANTQ         |      0      |      6      |     12      |     18      |       |
| PLACE_QUEUE         |      1      |      7      |     13      |     19      |       |
| PLACE_CPU           |      2      |      8      |     14      |     20      |       |
| PLACE_TOEXEC        |      3      |      9      |     15      |     21      |       |
| PLACE_EXECUTING     |      4      |     10      |     16      |     22      |       |
| PLACE_SUSPENDED     |      5      |     11      |     17      |     23      |       |
|                     |             |             |             |             |       |
| PLACE_GLOBAL_QUEUE  |             |             |             |             |  24   |
| PLACE_SMP_NOT_READY |             |             |             |             |  25   |
| PLACE_SMP_READY     |             |             |             |             |  26   |

## Transiciones

| Código                   | index PROC0 | index PROC1 | index PROC2 | index PROC3 | index |
| ------------------------ | :---------: | :---------: | :---------: | :---------: | :---: |
| TRAN_ADDTOQUEUE          |      0      |     11      |     22      |     33      |       |
| TRAN_UNQUEUE             |      1      |     12      |     23      |     34      |       |
| TRAN_EXEC                |      2      |     13      |     24      |     35      |       |
| TRAN_EXEC_EMPTY          |      3      |     14      |     25      |     36      |       |
| TRAN_RETURN_VOL          |      4      |     15      |     26      |     37      |       |
| TRAN_RETURN_INVOL        |      5      |     16      |     27      |     38      |       |
| TRAN_FROM_GLOBAL_CPU     |      6      |     17      |     28      |     39      |       |
| TRAN_REMOVE_QUEUE        |      7      |     18      |     29      |     40      |       |
| TRAN_REMOVE_EMPTY_QUEUE  |      8      |     19      |     30      |     41      |       |
| TRAN_SUSPEND_PROC        |      9      |     20      |     31      |     42      |       |
| TRAN_WAKEUP_PROC         |     10      |     21      |     32      |     43      |       |
|                          |             |             |             |             |       |
| TRAN_REMOVE_GLOBAL_QUEUE |             |             |             |             |  44   |
| TRAN_START_SMP           |             |             |             |             |  45   |
| TRAN_THROW               |             |             |             |             |  46   |
| TRAN_QUEUE_GLOBAL        |             |             |             |             |  47   |

## Jerárquicas

| hierarchical_transitions | hierarchical_corresponse |
| ------------------------ | ------------------------ |
| TRAN_ADDTOQUEUE          | TRAN_ON_QUEUE            |
| TRAN_EXEC                | TRAN_SET_RUNNING         |
| TRAN_EXEC_EMPTY          | TRAN_SET_RUNNING         |
| TRAN_RETURN_INVOL        | TRAN_SWITCH_OUT          |
| TRAN_RETURN_VOL          | TRAN_TO_WAIT_CHANNEL     |
| TRAN_REMOVE_QUEUE        | TRAN_REMOVE              |
| TRAN_REMOVE_EMPTY_QUEUE  | TRAN_REMOVE              |
| TRAN_QUEUE_GLOBAL        | TRAN_ON_QUEUE            |
| TRAN_REMOVE_GLOBAL_QUEUE | TRAN_REMOVE              |
