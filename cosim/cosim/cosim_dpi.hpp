#ifndef _COSIM_DPI_H_
#define _COSIM_DPI_H_

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include "cosim.hpp"

extern "C" int cosim_dpi_init_unified(
    char *sram_path,
    uint32_t pc_reset,
    uint32_t pc_xcpt,
    uint32_t mem_dlen
);

extern "C" int cosim_dpi_init(
    char *rom_path,
    char *sram_path,
    uint32_t pc_reset,
    uint32_t pc_xcpt,
    uint32_t mem_dlen
);

extern "C" unsigned int cosim_dpi_step(
    unsigned int *pc,
    unsigned int *ins,
    unsigned int *rd
);

#endif
