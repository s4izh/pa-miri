import datapath_pkg::*;

module rv32i_decoder #(
    parameter int XLEN = 32
)(
    input  logic [XLEN-1:0]   ins_i,
    
    // outputs for datapath control
    output alu_op_e          alu_op_o,
    output mux_alu_a_sel_e   alu_a_sel_o,
    output mux_alu_b_sel_e   alu_b_sel_o,
    output mux_wb_sel_e      wb_sel_o,

    output mux_pc_sel_e      pc_sel_o,
    output logic             illegal_ins_o,
    
    // write enable signals
    output logic             is_wb,
    output logic             is_ld,
    output logic             is_st,
    
    // decoded instruction fields
    output logic [4:0]        rs1_addr_o,
    output logic [4:0]        rs2_addr_o,
    output logic [4:0]        rd_addr_o,
    output logic [XLEN-1:0]   immed_o
);
    logic [6:0] opcode = ins_i[6:0];
    logic [2:0] funct3 = ins_i[14:12];
    logic [6:0] funct7 = ins_i[31:25];

    // When loading an immediate we previously used a MUX
    // to select between rs1, pc or zero.
    // Since we are in riscv we can simplify this by using the
    // x0 register (which is always zero) for the zero case.
    // effectively, turning a 3 to 1 MUX into a 2 to 1 MUX. 
    assign rs1_addr_o = (opcode == OPCODE_LUI) ? 5'b0 : ins_i[19:15];
    assign rs2_addr_o = ins_i[24:20];
    assign rd_addr_o  = ins_i[11:7];

    always_comb begin
        case (opcode)
            OPCODE_LUI,
            OPCODE_AUIPC: // U-Type
                immed_o = {ins_i[31:12], 12'b0};
            OPCODE_JAL:   // J-Type
                immed_o = { {12{ins_i[31]}}, ins_i[19:12], ins_i[20], ins_i[30:21], 1'b0 };
            OPCODE_JALR:  // I-Type
                immed_o = { {21{ins_i[31]}}, ins_i[30:20] };
            OPCODE_BRANCH: // B-Type
                immed_o = { {20{ins_i[31]}}, ins_i[7], ins_i[30:25], ins_i[11:8], 1'b0 };
            OPCODE_LOAD,
            OPCODE_IMM,
            OPCODE_FENCE,
            OPCODE_SYSTEM: // I-Type
                immed_o = { {21{ins_i[31]}}, ins_i[30:20] };
            OPCODE_STORE:  // S-Type
                immed_o = { {21{ins_i[31]}}, ins_i[30:25], ins_i[11:7] };
            default:
                immed_o = 32'b0;
        endcase
    end

    always_comb begin
        alu_op_o      = ALU_ADD;
        pc_sel_o      = PC_PLUS_4;
        alu_a_sel_o   = MUX_ALU_A_RS1;
        alu_b_sel_o   = MUX_ALU_B_RS2;
        wb_sel_o      = MUX_WB_ALU;
        is_wb         = 1'b0;
        is_ld         = 1'b0;
        ls_st         = 1'b0;

        case (opcode)
            // x[rd] = sext(immediate[31:12] << 12)
            OPCODE_LUI: begin
                is_wb       = 1'b1;
                alu_a_sel_o = MUX_ALU_A_RS1; // rs1_addr_o should be x0
                alu_b_sel_o = MUX_ALU_B_IMM;
                alu_op_o    = ALU_ADD; // x[rd] = 0 + imm
            end

            // x[rd] = pc + sext(immediate[31:12] << 12)
            OPCODE_AUIPC: begin
                is_wb       = 1'b1;
                alu_a_sel_o = MUX_ALU_A_PC;
                alu_b_sel_o = MUX_ALU_B_IMM;
                alu_op_o    = ALU_ADD; // x[rd] = pc + imm
            end

            // x[rd] = pc+4; pc += sext(offset)
            OPCODE_JAL: begin
                is_wb       = 1'b1;
                pc_sel_o    = PC_JUMP;
                wb_sel_o    = MUX_WB_PC4; // x[rd] = pc+4, pc = pc + imm
            end

            // TODO: t = pc+4; pc=(x[rs1]+sext(offset))&∼1; x[rd]=t
            OPCODE_JALR: begin
                is_wb       = 1'b1;
                pc_sel_o    = PC_JUMP;
                wb_sel_o    = MUX_WB_PC4; // write PC+4 to rd
            end

            OPCODE_BRANCH: begin
                // TODO: branch logic unit will use funct3 to decide BEQ, BNE, BLT etc.
                // We can't use alu since alu is needed for address calculation.
                // We need a separated subtractor unit that
                // should substract rs1 - rs2 and set a sign flag and equal flag.
            end

            // TODO: load types (LB, LH, LW, LBU, LHU), funct3 decides which one
            // is it really needed? or we can handle it in the memory stage?
            // 
            // We could need it here to detect and invalid alignment early
            // but I don't know if it's even possible for the instructions
            // to have a misaligned offset, maybe LW omits directly the last 4 bits
            // SHOULD check the spec
            OPCODE_LOAD: begin
                is_wb       = 1'b1;
                is_ld       = 1'b1;
                alu_b_sel_o = MUX_ALU_B_IMM;
                alu_op_o    = ALU_ADD; // address calculation: rs1 + imm
                wb_sel_o    = MUX_WB_MEM; // result comes from dmem
            end

            // store types (SB, SH, SW), funct3 decides which one
            OPCODE_STORE: begin
                is_st       = 1'b1;
                alu_b_sel_o = MUX_ALU_B_IMM;
                alu_op_o    = ALU_ADD; // address calculation: rs1 + imm
            end

            OPCODE_IMM: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                is_wb       = 1'b1;
                alu_b_sel_o = MUX_ALU_B_IMM;
                // ALU operation depends on funct3
                case (funct3)
                    F3_ADDI:  alu_op_o = ALU_ADD;
                    F3_SLTI:  alu_op_o = ALU_SLT;
                    F3_SLTIU: alu_op_o = ALU_SLTU;
                    F3_XORI:  alu_op_o = ALU_XOR;
                    F3_ORI:   alu_op_o = ALU_OR;
                    F3_ANDI:  alu_op_o = ALU_AND;
                    F3_SLLI:  alu_op_o = ALU_SLL;
                    F3_SRI:   alu_op_o = (funct7 == F7_SRA) ? ALU_SRA : ALU_SRL;
                    default:  illegal_ins_o = 1'b1;
                endcase
            end

            OPCODE_OP: begin // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
                is_wb       = 1'b1;
                // ALU operation depends on funct3 and funct7
                case (funct3)
                    F3_ADDSUB: alu_op_o = (funct7 == F7_SUB) ? ALU_SUB : ALU_ADD;
                    F3_SLL:    alu_op_o = ALU_SLL;
                    F3_SLT:    alu_op_o = ALU_SLT;
                    F3_SLTU:   alu_op_o = ALU_SLTU;
                    F3_XOR:    alu_op_o = ALU_XOR;
                    F3_SR:     alu_op_o = (funct7 == F7_SRA) ? ALU_SRA : ALU_SRL;
                    F3_OR:     alu_op_o = ALU_OR;
                    F3_AND:    alu_op_o = ALU_AND;
                    default:   illegal_ins_o = 1'b1;
                endcase
            end

            // we can ignore fences and others for now
            OPCODE_FENCE,
            OPCODE_SYSTEM: begin
                // logic
            end

            default: begin
                illegal_ins_o = 1'b1;
            end
        endcase
    end

endmodule
