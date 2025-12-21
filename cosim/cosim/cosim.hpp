#pragma once

#include "rve/cpu.h"
#include "rve/decoder.h"
#include <map>

typedef struct {
    uint32_t mtvec;
    uint32_t mepc;
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

trap_t cosim_execute(cosim_t *soc, decoded_instruction_t *di);
