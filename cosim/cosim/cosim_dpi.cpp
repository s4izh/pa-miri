#include "cosim_dpi.hpp"
#include "cosim_dpi_util.hpp"
#include "cosim.hpp"
#include "rve/decoder.h"
#include <cstdint>
#include <cstdio>

// Global instance
static cosim_t g_cosim;

extern "C" int cosim_dpi_init(
        char *rom_path,
        char *sram_path,
        uint32_t pc_reset,
        uint32_t pc_xcpt
) {
    FILE *rom_fd, *sram_fd;

    // Set struct things
    g_cosim.hart.pc = pc_reset;
    g_cosim.pc_reset = pc_reset;
    g_cosim.hart.csr.mtvec = pc_xcpt;
    // Open rom file
    if ((rom_fd = fopen(rom_path, "r")) == NULL) {
        return -1;
    }
    // Open sram file
    if ((sram_fd = fopen(sram_path, "r")) == NULL) {
        return -1;
    }
    // Read rom
    if (read_file_to_map(rom_fd, &g_cosim.imem) != 0) {
        return -1;
    }
    // Read sram
    if (read_file_to_map(sram_fd, &g_cosim.dmem) != 0) {
        return -1;
    }
    // Close files
    fclose(rom_fd);
    fclose(sram_fd);
    // All ok
    return 0;
}

extern "C" unsigned int cosim_dpi_step(
        unsigned int *pc,
        unsigned int *ins,
        unsigned int *rd
) {
    decoded_instruction_t di;
    int pc_now;
    *pc = g_cosim.hart.pc;
    *ins = g_cosim.imem[(*pc)>>2];
    di = rve_decode_instruction(*ins);
    trap_t trap = cosim_execute(&g_cosim, &di);
    *rd = g_cosim.hart.gpr[di.rd];
    return g_cosim.hart.pc;
}
