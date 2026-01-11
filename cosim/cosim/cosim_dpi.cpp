#include "cosim_dpi.hpp"
#include "cosim_dpi_util.hpp"
#include "cosim.hpp"
#include "rve/decoder.h"
#include <cstdint>
#include <cstdio>

// Global instance
static cosim_t g_cosim;

extern "C" int cosim_dpi_init_unified(
        char *sram_path,
        uint32_t pc_reset,
        uint32_t pc_xcpt,
        uint32_t mem_dlen
) {
    FILE *rom_fd, *sram_fd;

    // Set struct things
    g_cosim.hart.pc = pc_reset;
    g_cosim.pc_reset = pc_reset;
    g_cosim.hart.csr.mtvec = pc_xcpt;
    g_cosim.is_unified_mem = true;
    // Open sram file
    if ((sram_fd = fopen(sram_path, "r")) == NULL) {
        return -1;
    }
    // Read sram
    if (read_file_to_map(sram_fd, &g_cosim.dmem, mem_dlen/8) != 0) {
        return -1;
    }
    // Close files
    fclose(sram_fd);
    // All ok
    return 0;
}

extern "C" int cosim_dpi_init(
        char *rom_path,
        char *sram_path,
        uint32_t pc_reset,
        uint32_t pc_xcpt,
        uint32_t mem_dlen
) {
    FILE *rom_fd, *sram_fd;

    // Set struct things
    g_cosim.hart.pc = pc_reset;
    g_cosim.pc_reset = pc_reset;
    g_cosim.hart.csr.mtvec = pc_xcpt;
    g_cosim.is_unified_mem = false;
    // Open rom file
    if ((rom_fd = fopen(rom_path, "r")) == NULL) {
        return -1;
    }
    // Open sram file
    if ((sram_fd = fopen(sram_path, "r")) == NULL) {
        return -1;
    }
    // Read rom
    if (read_file_to_map(rom_fd, &g_cosim.imem, mem_dlen/8) != 0) {
        return -1;
    }
    // Read sram
    if (read_file_to_map(sram_fd, &g_cosim.dmem, mem_dlen/8) != 0) {
        return -1;
    }
    // Close files
    fclose(rom_fd);
    fclose(sram_fd);
    // All ok
    return 0;
}

void print_hart(const hart_t& hart) {
    printf("PC: 0x%08X\n", hart.pc);
    printf("GPRs:\n");
    for (int i = 0; i < 32; ++i) {
        printf("x%-2d: 0x%08X ", i, hart.gpr[i]);
        // Print a newline every 4 registers for better readability
        if ((i + 1) % 4 == 0) {
            printf("\n");
        }
    }
    printf("\n");
}

extern "C" unsigned int cosim_dpi_step(
        unsigned int *pc,
        unsigned int *ins,
        unsigned int *rd
) {
    decoded_instruction_t di;
    int pc_now;
    *pc = g_cosim.hart.pc;
    if (g_cosim.is_unified_mem) *ins = g_cosim.dmem[(*pc)>>2];
    else                        *ins = g_cosim.imem[(*pc)>>2];
    di = rve_decode_instruction(*ins);
#if 0
    char buffer[32];
    if (di.valid) {
        rve_decoded_format_to_buffer(&di, buffer, sizeof(buffer));
        u32 column_width = 25;
        printf("%-*s Decoded: %s, Format: %s, Imm: 0x%08X, Rd: %d, Rs1: %d, Rs2: %d\n",
               column_width, buffer, rve_instruction_op_to_cstr(di.op),
               rve_instruction_format_to_cstr(di.format), di.imm, di.rd,
               di.rs1, di.rs2);
        print_hart(g_cosim.hart);

    } else {
        printf("Invalid instruction: 0x%08X\n", *ins);
    }
#endif
    trap_t trap = cosim_execute(&g_cosim, &di);
    *rd = g_cosim.hart.gpr[di.rd];
    return (trap == TRAP_ERR) ? 1 : 0;
}
