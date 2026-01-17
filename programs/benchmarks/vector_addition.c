#define SIZE 16

int main() {
    int vecA[SIZE];
    int vecB[SIZE];
    int vecR[SIZE];

    for(int i = 0; i < SIZE; i++) {
        vecA[i] = i;
        vecB[i] = i * 2;
    }

    for(int i = 0; i < SIZE; i++) {
        vecR[i] = vecA[i] + vecB[i];
    }

    return 0;
}
