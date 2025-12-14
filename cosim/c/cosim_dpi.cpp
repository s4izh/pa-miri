#include "cosim_dpi.hpp"

uint32_t hex_to_int(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'a' && c <= 'f') {
        return c - 'a';
    } else if (c >= 'A' && c <= 'F') {
        return c - 'A';
    }
    return 0;
}

// pre: line is a \n terminated string
uint32_t hex_to_int(char *line) {
    uint32_t ret = 0;
    while (*line != '\n') {
        ret = (ret << 4) + hex_to_int(*line);
        ++line;
    }
    return ret;
}

// Global instance
cosim_t cosim_inst;

extern "C" int cosim_dpi_init(char *rom_path, char *sram_path, uint32_t pc_reset, uint32_t pc_xcpt) {
    char *line;
    size_t len;
    ssize_t read_len;
    FILE *rom_fd, *sram_fd;
    uint32_t current_addr;

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
    len = 0;
    current_addr = cosim_inst.pc_reset/sizeof(uint32_t);
    while ((read_len = getline(&line, &len, rom_fd)) != -1) {
        if (read_len <= 1) {
            // Nothing to parse
            continue;
        }
        if (line[0] == '@') {
            // Parse an address
            current_addr = hex_to_int(line+1);
            printf("Address set: 0x%x\n", current_addr);
            continue;
        }
        // We parse data
        cosim_inst.imem.insert({current_addr, hex_to_int(line)});
        printf("Address written: {0x%x, 0x%x}\n", current_addr, hex_to_int(line));
        current_addr++;
    }
    // Read sram
    len = 0;
    current_addr = 0x3000/sizeof(uint32_t);
    while ((read_len = getline(&line, &len, sram_fd)) != -1) {
        if (read_len <= 1) {
            // Nothing to parse
            continue;
        }
        if (line[0] == '@') {
            // Parse an address
            current_addr = hex_to_int(line+1);
            printf("Address set: 0x%x\n", current_addr);
            continue;
        }
        // We parse data
        cosim_inst.dmem.insert({current_addr, hex_to_int(line)});
        printf("Address written: {0x%x, 0x%x}\n", current_addr, hex_to_int(line));
        current_addr++;
    }
    // Close files
    fclose(rom_fd);
    fclose(sram_fd);
    // All ok
    return 0;
}

extern "C" int cosim_dpi_step() {
    int pc_now = cosim_inst.hart.pc;
    // Execute instruction with pc=pc_now
    // ...
    cosim_inst.hart.pc += 4;
    return pc_now;
}
