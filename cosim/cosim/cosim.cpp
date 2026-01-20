#include "cosim.hpp"
#include "rve/types.h"

static inline word sext(word value, u32 size) {
	return (s_word)(value << (XLEN - size)) >> (XLEN - size);
}

static bool cosim_dmem_read(cosim_t *soc, u32 addr, u8 len, word *value) {
    uint32_t v = soc->dmem[addr>>2];
    uint32_t shift;
    uint32_t mask;
    switch (len) {
        case 8:
            shift = len*(addr & 0b11);
            mask = 0xff;
            break;
        case 16:
            if (addr & 0b1) return false;
            shift = len*((addr >> 1) & 0b1);
            mask = 0xffff;
            break;
        case 32:
            if (addr & 0b11) return false;
            shift = 0;
            mask = 0xffffffff;
            break;
        default:
            return false;
            break;
    };
    *value = (v >> shift) & mask;
    return true;
}

static bool cosim_dmem_write(cosim_t *soc, u32 addr, u8 len, word value) {
    uint32_t mask;
    uint32_t shift;
    uint32_t v = soc->dmem[addr>>2];
    switch (len) {
        case 8:
            shift = len*(addr & 0b11);
            mask = 0xff;
            break;
        case 16:
            if (addr & 0b1) return false;
            shift = len*((addr >> 1) & 0b1);
            mask = 0xffff;
            break;
        case 32:
            if (addr & 0b11) return false;
            shift = 0;
            mask = 0xffffffff;
            break;
        default:
            return false;
            break;
    };
    mask <<= shift;
    v = (value << shift) & mask | v & ~mask;
    soc->dmem[addr>>2] = v;
    return true;
}

typedef enum {
    CSR_OP_RW,
    CSR_OP_RS,
    CSR_OP_RC,
} csr_op_e;

static trap_t cosim_perform_csr_op(cosim_t *soc, decoded_instruction_t *di, uint32_t *csr, csr_op_e csr_op, bool uimm_valid) {
    uint32_t tmp_new_rd, tmp_new_csr;
    // Assign new rd value
    tmp_new_rd = *csr;
    // Assign new csr value
    switch (csr_op) {
        case CSR_OP_RW:
            if (uimm_valid) tmp_new_csr = (uint32_t)di->rs1;
            else            tmp_new_csr = soc->hart.gpr[di->rs1];
            break;
        case CSR_OP_RS:
            if (uimm_valid) tmp_new_csr = tmp_new_rd | (uint32_t)di->rs1;
            else            tmp_new_csr = tmp_new_rd | soc->hart.gpr[di->rs1];
            break;
        case CSR_OP_RC:
            if (uimm_valid) tmp_new_csr = tmp_new_rd & ~(uint32_t)di->rs1;
            else            tmp_new_csr = tmp_new_rd & ~soc->hart.gpr[di->rs1];
            break;
    };
    if (di->rd != 0) soc->hart.gpr[di->rd] = tmp_new_rd;
    if (di->rs1 != 0) *csr = tmp_new_csr;
    return TRAP_OK;
}

static trap_t cosim_csr_op(cosim_t *soc, decoded_instruction_t *di, csr_op_e csr_op, bool uimm_valid) {
    switch ((di->original_instruction >> 20)) {
        case 0x305: return cosim_perform_csr_op(soc, di, &soc->hart.csr.mtvec , csr_op, uimm_valid);
        case 0x341: return cosim_perform_csr_op(soc, di, &soc->hart.csr.mepc  , csr_op, uimm_valid);
        case 0x342: return cosim_perform_csr_op(soc, di, &soc->hart.csr.mcause, csr_op, uimm_valid);
        case 0x343: return cosim_perform_csr_op(soc, di, &soc->hart.csr.mtval , csr_op, uimm_valid);
    };
    return TRAP_ERR;
}

trap_t cosim_execute(cosim_t *soc, decoded_instruction_t *di) {
    bool update_pc = true;
	dword tmp_overflow;
	word value = 0;
    word read_value = 0;
	trap_t trap = TRAP_OK;

    if (soc->hart.pc & 0b11) {
        trap = TRAP_ERR;
        goto trap;
    }

	switch (di->op) {
		case INSTRUCTION_OP_LUI:
			soc->hart.gpr[di->rd] = di->imm; // di->imm already shifted <<12 by the decoder
			break;
		case INSTRUCTION_OP_AUIPC:
			soc->hart.gpr[di->rd] = soc->hart.pc + (di->imm);
			break;
		case INSTRUCTION_OP_JAL:
			soc->hart.gpr[di->rd] = soc->hart.pc + 4;
			soc->hart.pc += sext(di->imm, 21);
            update_pc = false;
			break;
		case INSTRUCTION_OP_JALR:
            value = soc->hart.pc + 4;
            soc->hart.pc = (soc->hart.gpr[di->rs1] + sext(di->imm, 12)) & ~(word)1;
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
			if (!cosim_dmem_read(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 8, &read_value)) {
				trap = TRAP_ERR;
                break;
			}
			soc->hart.gpr[di->rd] = sext(read_value, 8);
			break;
		case INSTRUCTION_OP_LH:
			if (!cosim_dmem_read(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 16, &read_value)) {
				trap = TRAP_ERR;
                break;
			}
			soc->hart.gpr[di->rd] = sext(read_value, 16);
			break;
		case INSTRUCTION_OP_LW:
			if (!cosim_dmem_read(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 32, &read_value)) {
				trap = TRAP_ERR;
                break;
			}
			soc->hart.gpr[di->rd] = sext(read_value, 32);
			break;
		case INSTRUCTION_OP_LBU:
			if (!cosim_dmem_read(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 8, &read_value)) {
				trap = TRAP_ERR;
                break;
			}
			soc->hart.gpr[di->rd] = read_value;
			break;
		case INSTRUCTION_OP_LHU:
			if (!cosim_dmem_read(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 16, &read_value)) {
				trap = TRAP_ERR;
                break;
			}
			soc->hart.gpr[di->rd] = read_value;
			break;
		case INSTRUCTION_OP_SB:
			value = soc->hart.gpr[di->rs2] & 0xFF;
			if (!cosim_dmem_write(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 8, value)) {
				trap = TRAP_ERR;
			}
			break;
		case INSTRUCTION_OP_SH:
			value = soc->hart.gpr[di->rs2] & 0xFFFF;
			if (!cosim_dmem_write(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 16, value)) {
				trap = TRAP_ERR;
			}
			break;
		case INSTRUCTION_OP_SW:
			value = soc->hart.gpr[di->rs2];
			if (!cosim_dmem_write(soc, soc->hart.gpr[di->rs1] + sext(di->imm, 12), 32, value)) {
				trap = TRAP_ERR;
			}
			break;
		case INSTRUCTION_OP_ADDI:
			soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] + sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_SLTI:
			soc->hart.gpr[di->rd] = (s_word)soc->hart.gpr[di->rs1] < (s_word)sext(di->imm, 12);
			break;
		case INSTRUCTION_OP_SLTIU:
			// soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] < di->imm;
            soc->hart.gpr[di->rd] = soc->hart.gpr[di->rs1] < (word)sext(di->imm, 12);
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
        // Muldiv (M extension)
        case INSTRUCTION_OP_MUL:
			soc->hart.gpr[di->rd] = ((i64)soc->hart.gpr[di->rs1] * (i64)soc->hart.gpr[di->rs2]);
            break;
        case INSTRUCTION_OP_MULH:
            i64 tmp;
            tmp = (i32)soc->hart.gpr[di->rs1] * (i32)soc->hart.gpr[di->rs2];
            tmp = tmp >> 32;
			soc->hart.gpr[di->rd] = tmp;
            break;
        case INSTRUCTION_OP_MULHSU:
			soc->hart.gpr[di->rd] = ((i64)soc->hart.gpr[di->rs1] * (u64)soc->hart.gpr[di->rs2]) >> 32;
            break;
        case INSTRUCTION_OP_MULHU:
			soc->hart.gpr[di->rd] = ((u64)soc->hart.gpr[di->rs1] * (u64)soc->hart.gpr[di->rs2]) >> 32;
            break;
        case INSTRUCTION_OP_DIV:
            if (soc->hart.gpr[di->rs2] == 0) {
				trap = TRAP_ERR;
            } else {
                soc->hart.gpr[di->rd] = ((i32)soc->hart.gpr[di->rs1] / (i32)soc->hart.gpr[di->rs2]);
            }
            break;
        case INSTRUCTION_OP_DIVU:
            if (soc->hart.gpr[di->rs2] == 0) {
				trap = TRAP_ERR;
            } else {
                soc->hart.gpr[di->rd] = ((u32)soc->hart.gpr[di->rs1] / (u32)soc->hart.gpr[di->rs2]);
            }
            break;
        case INSTRUCTION_OP_REM:
            if (soc->hart.gpr[di->rs2] == 0) {
				trap = TRAP_ERR;
            } else {
                soc->hart.gpr[di->rd] = ((i32)soc->hart.gpr[di->rs1] % (i32)soc->hart.gpr[di->rs2]);
            }
            break;
        case INSTRUCTION_OP_REMU:
            if (soc->hart.gpr[di->rs2] == 0) {
				trap = TRAP_ERR;
            } else {
                soc->hart.gpr[di->rd] = ((u32)soc->hart.gpr[di->rs1] % (u32)soc->hart.gpr[di->rs2]);
            }
            break;
        // Unimplemented
		case INSTRUCTION_OP_FENCE:
		case INSTRUCTION_OP_FENCE_I:
            // fences do nothing on cosim
            break;
		case INSTRUCTION_OP_CSRRW:  trap = cosim_csr_op(soc, di, CSR_OP_RW, false); break;
		case INSTRUCTION_OP_CSRRS:  trap = cosim_csr_op(soc, di, CSR_OP_RS, false); break;
		case INSTRUCTION_OP_CSRRC:  trap = cosim_csr_op(soc, di, CSR_OP_RC, false); break;
		case INSTRUCTION_OP_CSRRWI: trap = cosim_csr_op(soc, di, CSR_OP_RW, true) ; break;
		case INSTRUCTION_OP_CSRRSI: trap = cosim_csr_op(soc, di, CSR_OP_RS, true) ; break;
		case INSTRUCTION_OP_CSRRCI: trap = cosim_csr_op(soc, di, CSR_OP_RC, true) ; break;

		case INSTRUCTION_OP_ECALL:
		case INSTRUCTION_OP_EBREAK:
			fprintf(stderr, "UNIMPLEMENTED: %s\n", rve_instruction_op_to_cstr(di->op));
			trap = TRAP_ERR;
			break;
		default:
			fprintf(stderr, "ERROR: Unknown instruction: %d\n", di->op);
			trap = TRAP_ERR;
			break;
	}

trap:
    if (trap == TRAP_OK) {
        if (update_pc)
            soc->hart.pc += 4;
    } else {
        soc->hart.csr.mepc = soc->hart.pc;
        soc->hart.pc = soc->hart.csr.mtvec;
    }

	soc->hart.gpr[0] = 0;
	return trap;
}
