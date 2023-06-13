CC = gcc
CFLAGS = -Wall -Wextra -pthread

single_thread_multiplier: single_thread_multiplier.o
	$(CC) $(CFLAGS) single_thread_multiplier.o -o single_thread_multiplier

single_thread_multiplier.o: single_thread_multiplier.c
	$(CC) $(CFLAGS) -c single_thread_multiplier.c

clean:
	rm -f single_thread_multiplier single_thread_multiplier.o