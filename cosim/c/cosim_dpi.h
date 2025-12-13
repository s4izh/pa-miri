#ifndef _COSIM_DPI_H_
#define _COSIM_DPI_H_

// #include <stdint.h>
//
// typedef struct {
//     uint32_t pc;
//     uint32_t ins;
//     uint32_t gpr[32];
// } dpi_t;
//
// void dpi_init(char *rom_path, char *sram_path, uint32_t pc_reset,
//         uint32_t pc_xpct);

int cosim_dpi_step(int n);

// dpi_t dpi_get_current();

#endif
