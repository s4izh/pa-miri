#include "cosim.hpp"
#include "rve/types.h"

static inline word sext(word value, u32 size) {
	return (s_word)(value << (XLEN - size)) >> (XLEN - size);
}

static bool cosim_dmem_read(cosim_t *soc, u32 addr, u8 len, word *value) {
    uint32_t v = soc->dmem[addr>>2];
    switch (len) {
        case 8:
            *value = (0x000000ff << (len*(addr & 0b11))) & v;
            *value = *value >> (len*(addr & 0b11));
            break;
        case 16:
            if (addr & 0b1) return false;
            *value = (0x0000ffff << (len*(addr & (0b10 >> 1)))) & v;
            *value = *value >> (len*(addr & (0b10 >> 1)));
            break;
        case 32:
            if (addr & 0b11) return false;
            *value = v;
            break;
        default:
            return false;
            break;
    };
    return true;
}

static bool cosim_dmem_write(cosim_t *soc, u32 addr, u8 len, word value) {
    uint32_t mask;
    uint32_t aligned_value;
    uint32_t v = soc->dmem[addr>>2];
    switch (len) {
        case 8:
            mask = 0x000000ff << (len*(addr & 0b11));
            aligned_value = value << (len*(addr & 0b11));
            break;
        case 16:
            if (addr & 0b1) return false;
            mask = 0x0000ffff << (len*(addr & (0b10 >> 1)));
            aligned_value = value << (len*(addr & (0b10 >> 1)));
            break;
        case 32:
            if (addr & 0b11) return false;
            mask = 0xffffffff;
            aligned_value = value;
            break;
        default:
            return false;
            break;
    };
    v = aligned_value & mask | v & ~mask;
    soc->dmem[addr>>2] = v;
    return true;
}

trap_t cosim_execute(cosim_t *soc, decoded_instruction_t *di) {
    bool update_pc = true;
	dword tmp_overflow;
	word value = 0;
    word read_value = 0;
	trap_t trap = TRAP_OK;

	switch (di->op) {
		case INSTRUCTION_OP_LUI:
			soc->hart.gpr[di->rd] = (di->imm << 12) & 0x000;
			break;
		case INSTRUCTION_OP_AUIPC:
			soc->hart.gpr[di->rd] = soc->hart.pc + ((di->imm << 12) & 0x000);
			break;
		case INSTRUCTION_OP_JAL:
			soc->hart.gpr[di->rd] = soc->hart.pc + 4;
			soc->hart.pc += sext(di->imm, 21);
            update_pc = false;
			break;
		case INSTRUCTION_OP_JALR:
			value = soc->hart.pc + 4;
			soc->hart.pc = (di->rs1 + sext(di->imm, 12)) & ~(word)1;
			soc->hart.gpr[di->rd] = value;
            update_pc = false;
			break;
		case INSTRUCTION_OP_BEQ:
			if (soc->hart.gpr[di->rs1] == soc->hart.gpr[di->rs2]) {
				soc->hart.pc += sext(di->imm, 13);
                update_pc = false;
            }
			break;
		case INSTRUCTION_OP_BNE:
			if (soc->hart.gpr[di->rs1] != soc->hart.gpr[di->rs2]) {
				soc->hart.pc += sext(di->imm, 13);
                update_pc = false;
            }
			break;
		case INSTRUCTION_OP_BLT:
			if ((s_word)soc->hart.gpr[di->rs1] < (s_word)soc->hart.gpr[di->rs2]) {
				soc->hart.pc += sext(di->imm, 13);
                update_pc = false;
            }
			break;
		case INSTRUCTION_OP_BGE:
			if ((s_word)soc->hart.gpr[di->rs1] >= (s_word)soc->hart.gpr[di->rs2]) {
				soc->hart.pc += sext(di->imm, 13);
                update_pc = false;
            }
			break;
		case INSTRUCTION_OP_BLTU:
			if (soc->hart.gpr[di->rs1] < soc->hart.gpr[di->rs2]) {
				soc->hart.pc += sext(di->imm, 13);
                update_pc = false;
            }
			break;
		case INSTRUCTION_OP_BGEU:
			if (soc->hart.gpr[di->rs1] >= soc->hart.gpr[di->rs2]) {
				soc->hart.pc += sext(di->imm, 13);
                update_pc = false;
            }
			break;
		case INSTRUCTION_OP_LB:
			if (!cosim_dmem_read(soc, di->rs1 + sext(di->imm, 12), 8, &read_value)) {
				trap = TRAP_ERR;
			}
			soc->hart.gpr[di->rd] = sext(value, 8);
			break;
		case INSTRUCTION_OP_LH:
			if (!cosim_dmem_read(soc, di->rs1 + sext(di->imm, 12), 16, &read_value)) {
				trap = TRAP_ERR;
			}
			soc->hart.gpr[di->rd] = sext(value, 16);
			break;
		case INSTRUCTION_OP_LW:
			if (!cosim_dmem_read(soc, di->rs1 + sext(di->imm, 12), 32, &read_value)) {
				trap = TRAP_ERR;
			}
			soc->hart.gpr[di->rd] = sext(value, 32);
			break;
		case INSTRUCTION_OP_LBU:
			if (!cosim_dmem_read(soc, di->rs1 + sext(di->imm, 12), 8, &read_value)) {
				trap = TRAP_ERR;
			}
			soc->hart.gpr[di->rd] = value;
			break;
		case INSTRUCTION_OP_LHU:
			if (!cosim_dmem_read(soc, di->rs1 + sext(di->imm, 12), 16, &read_value)) {
				trap = TRAP_ERR;
			}
			soc->hart.gpr[di->rd] = value;
			break;
		case INSTRUCTION_OP_SB:
			value = di->rs2 & 0xFF;
			if (!cosim_dmem_write(soc, di->rs1 + sext(di->imm, 7), 8, value)) {
				trap = TRAP_ERR;
			}
			break;
		case INSTRUCTION_OP_SH:
			value = di->rs2 & 0xFFFF;
			if (!cosim_dmem_write(soc, di->rs1 + sext(di->imm, 7), 16, value)) {
				trap = TRAP_ERR;
			}
			break;
		case INSTRUCTION_OP_SW:
			value = di->rs2;
			if (!cosim_dmem_write(soc, di->rs1 + sext(di->imm, 7), 32, value)) {
				trap = TRAP_ERR;
			}
			break;
		case INSTRUCTION_OP_ADDI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] + sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_SLTI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] < sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_SLTIU:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] < di->imm;
			break;
		case INSTRUCTION_OP_XORI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] ^ sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_ORI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] | sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_ANDI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] & sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_SLLI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] << di->imm;
			break;
		case INSTRUCTION_OP_SRLI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] >> di->imm;
			break;
		case INSTRUCTION_OP_SRAI:
			soc->hart.gpr[di->rd] = (s_word)soc->hart.gpr[di->rs1] >> di->imm;
			break;
		case INSTRUCTION_OP_ADD:
			tmp_overflow = (dword)soc->hart.gpr[di->rs1] + (dword)soc->hart.gpr[di->rs2];
			soc->hart.gpr[di->rd] = (word)(tmp_overflow & XLEN_MASK);
			break;
		case INSTRUCTION_OP_SUB:
			tmp_overflow = (dword)soc->hart.gpr[di->rs1] - (dword)soc->hart.gpr[di->rs2];
			soc->hart.gpr[di->rd] = (word)(tmp_overflow & XLEN_MASK);
			break;
		case INSTRUCTION_OP_SLL:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] << (soc->hart.gpr[di->rs2] & 0x1F);
			break;
		case INSTRUCTION_OP_SLT:
			soc->hart.gpr[di->rd] = (s_word)soc->hart.gpr[di->rs1] < (s_word)soc->hart.gpr[di->rs2];
			break;
		case INSTRUCTION_OP_SLTU:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] < soc->hart.gpr[di->rs2];
			break;
		case INSTRUCTION_OP_XOR:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] ^ soc->hart.gpr[di->rs2];
			break;
		case INSTRUCTION_OP_SRL:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] >> (soc->hart.gpr[di->rs2] & 0x1F);
			break;
		case INSTRUCTION_OP_SRA:
			soc->hart.gpr[di->rd] = (s_word)soc->hart.gpr[di->rs1] >> (soc->hart.gpr[di->rs2] & 0x1F);
			break;
		case INSTRUCTION_OP_OR:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] | soc->hart.gpr[di->rs2];
			break;
		case INSTRUCTION_OP_AND:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] & soc->hart.gpr[di->rs2];
			break;
		case INSTRUCTION_OP_FENCE:
		case INSTRUCTION_OP_FENCE_I:
		case INSTRUCTION_OP_ECALL:
		case INSTRUCTION_OP_EBREAK:
		case INSTRUCTION_OP_CSRRW:
		case INSTRUCTION_OP_CSRRS:
		case INSTRUCTION_OP_CSRRC:
		case INSTRUCTION_OP_CSRRWI:
		case INSTRUCTION_OP_CSRRSI:
		case INSTRUCTION_OP_CSRRCI:
			fprintf(stderr, "UNIMPLEMENTED: %s\n", rve_instruction_op_to_cstr(di->op));
			trap = TRAP_ERR;
			break;
		default:
			fprintf(stderr, "ERROR: Unknown instruction: %d\n", di->op);
			trap = TRAP_ERR;
			break;
	}

    if (trap == TRAP_OK) {
        if (update_pc)
            soc->hart.pc += 4;
    } else {
        soc->hart.pc = soc->hart.csr.mtvec;
    }

	soc->hart.gpr[0] = 0;
	return trap;
}
