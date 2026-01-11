#define N 128

int main() {
    int i,j,k;
    int a[N][N], b[N][N], c[N][N];
    for (i=0; i<N; i++) {
        for(j =0;j<N;j++) {
            c[i][j] = 0;
            for(k = 0; k <N; k++ ) {
                c[i][j] = c[i][j] + a[i][k] * b[k][j];
            }
        }
    }
    return 0;
}
