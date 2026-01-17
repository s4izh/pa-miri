#define M_SIZE 16
int matA[M_SIZE][M_SIZE];
int matB[M_SIZE][M_SIZE];

int main() {
    for(int i=0; i<M_SIZE; i++)
        for(int j=0; j<M_SIZE; j++)
            matA[i][j] = i + j;

    for(int i=0; i<M_SIZE; i++) {
        for(int j=0; j<M_SIZE; j++) {
            // Load row, Store column
            matB[j][i] = matA[i][j];
        }
    }
    return matB[0][0];
}
