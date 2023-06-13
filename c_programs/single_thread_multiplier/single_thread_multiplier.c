#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

void *count_seconds(void *arg)
{
  int i, j;
  double result = 0.0;

  while (1)
  {
    // Perform some calculations
    for (i = 0; i < 100000; i++)
    {
      for (j = 0; j < 1000; j++)
      {
        result += i * j;
      }
    }
  }
}

int main()
{
  pthread_t thread;
  int key;

  // Create a thread to count seconds
  pthread_create(&thread, NULL, count_seconds, NULL);

  // Wait for the user to press any key
  printf("Press any key to exit...\n");
  scanf("%d", &key);

  // Cancel the thread
  pthread_cancel(thread);
  pthread_join(thread, NULL);

  printf("Program terminated.\n");

  return 0;
}