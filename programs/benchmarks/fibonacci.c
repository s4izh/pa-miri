int fib(int n) {
    if (n <= 1) return n;
    return fib(n-1) + fib(n-2);
}

int main() {
    volatile int result = fib(20);
    return 0;
}
