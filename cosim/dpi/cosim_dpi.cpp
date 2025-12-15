#include "cosim_dpi.hpp"
#include "cosim_dpi_util.hpp"
#include "rve/decoder.h"
#include <cstdint>
#include <cstdio>

// Global instance
cosim_t cosim_inst;

extern "C" int cosim_dpi_init(char *rom_path, char *sram_path, uint32_t pc_reset, uint32_t pc_xcpt) {
    FILE *rom_fd, *sram_fd;

    // Set struct things
    cosim_inst.hart.pc = pc_reset;
    cosim_inst.pc_reset = pc_reset;
    cosim_inst.hart.csr.mtvec = pc_xcpt;
    // Open rom file
    if ((rom_fd = fopen(rom_path, "r")) == NULL) {
        return -1;
    }
    // Open sram file
    if ((sram_fd = fopen(sram_path, "r")) == NULL) {
        return -1;
    }
    // Read rom
    if (read_file_to_map(rom_fd, &cosim_inst.imem) != 0) {
        return -1;
    }
    // Read sram
    if (read_file_to_map(sram_fd, &cosim_inst.dmem) != 0) {
        return -1;
    }
    // Close files
    fclose(rom_fd);
    fclose(sram_fd);
    // All ok
    return 0;
}

extern "C" int cosim_dpi_step(unsigned int *pc, unsigned int *ins) {
    decoded_instruction_t di;
    int pc_now, active;
    char buff[100];
    *pc = cosim_inst.hart.pc;
    active = 1;

    // Execute instruction
    *ins = cosim_inst.imem[(*pc)>>2];
    di = rve_decode_instruction(*ins);
    rve_decoded_format_to_buffer(&di, buff, sizeof(buff));
    printf("Diassembled ins: %s\n", buff);

    cosim_inst.hart.pc += 4;
    return active;
}
