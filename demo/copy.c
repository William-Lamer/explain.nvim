#include <stdio.h>

void copy(char *dst, const char *src) {
    while ((*dst++ = *src++));
}

int main(void) {
    char buf[32];
    copy(buf, "hello, world");
    puts(buf);
    return 0;
}
