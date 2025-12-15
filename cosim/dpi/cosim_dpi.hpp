#ifndef _COSIM_DPI_H_
#define _COSIM_DPI_H_

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <map>
#include <sys/types.h>

typedef struct {
    uint32_t mtvec;
} csr_t;

typedef struct {
    uint32_t pc;
    uint32_t gpr[32];
    csr_t    csr;
} hart_t;

typedef struct {
    hart_t   hart;
    uint32_t pc_reset;
    std::map<uint32_t, uint32_t> imem;
    std::map<uint32_t, uint32_t> dmem;
} cosim_t;

extern "C" int cosim_dpi_init(char *rom_path, char *sram_path, uint32_t pc_reset, uint32_t pc_xcpt);
extern "C" int cosim_dpi_step(unsigned int *pc, unsigned int *ins);

#endif
