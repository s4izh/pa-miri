#define N 10

char source[N], destination[N];

void init_array(void *dst, long len) {
    char *pdst = (char*)dst;
    pdst[0] = 1;
    for (long i = 1; i < len; ++i) {
        pdst[i] = (pdst[i-1] << 4) + pdst[i-1];
    }
}

void* memcpy(void *dst, const void *src, long len) {
    for (long i = 0; i < len; ++i)
        ((char*)dst)[i] = ((char*)src)[i];
}

// int diff_cnt(const void *dst, const void *src, long len) {
//     int count = 0;
//     for (long i = 0; i < len; ++i)
//         count += ((char*)dst)[i] != ((char*)src)[i];
//     return count;
// }

int main() {
    init_array(source, N);
    memcpy(destination, source, N);
    // return diff_cnt(destination, source, N);
    return 0;
}
