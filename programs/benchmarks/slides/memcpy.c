#define N 128

int main() {
    int a[N], b[N];
    for (int i=0; i<N; i++) { a[i] = 5; }
    for (int i=0; i<N; i++) { b[i] = a[i]; }
    return 0;
}
