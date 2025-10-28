int main() {
    int a[128], b[128];
    for (int i=0; i<128; i++) { a[i] = 5; }
    for (int i=0; i<128; i++) { b[i] = a[i]; }
    return 0;
}
