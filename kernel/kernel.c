#include <mynix/mynix.h>

int magic = MYNIX_MAGIC;
char message[] = "Hello Mynix!!!";
char buf[1024];

void main(){
    char* video_memory = (char*) 0xb8000;
    *video_memory = 'X';
}