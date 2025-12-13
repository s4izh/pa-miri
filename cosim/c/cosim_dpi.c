#include "cosim_dpi.h"

// void dpi_init(char *rom_path, char *sram_path,
//         uint32_t pc_reset, uint32_t pc_xpct);

int cosim_dpi_step(int n) {
    static int acc = 0;
    acc += n;
    return acc;
}

// dpi_t dpi_get_current();
