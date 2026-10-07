#include <stdio.h>

int power(int base, int exp) {
    return base ** exp;
}

int main(void) {
    for (int i = 0; i <= 10; i++) {
        printf("2^%d = %d\n", i, power(2, i));
    }
    return 0;
}
