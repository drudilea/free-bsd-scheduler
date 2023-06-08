CC = gcc
CFLAGS = -Wall -Wextra -pthread

single_thread_counter: single_thread_counter.o
	$(CC) $(CFLAGS) single_thread_counter.o -o single_thread_counter

single_thread_counter.o: single_thread_counter.c
	$(CC) $(CFLAGS) -c single_thread_counter.c

clean:
	rm -f single_thread_counter single_thread_counter.o