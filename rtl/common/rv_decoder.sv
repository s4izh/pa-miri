import rv_datapath_pkg::*;
import memory_controller_pkg::*;
import alu_pkg::*;

module rv_decoder #(
    parameter int XLEN = 32
)(
    input  logic [31:0]   ins_i,

    // outputs for datapath control
    output alu_op_e          alu_op_o,
    output mux_alu_op1_sel_e   alu_op1_sel_o,
    output mux_alu_op2_sel_e   alu_op2_sel_o,
    output mux_wb_sel_e      wb_sel_o,

    output mux_pc_sel_e      pc_sel_o,
    output logic             illegal_ins_o,

    // write enable signals
    output logic             is_wb_o,
    output logic             is_ld_o, // kept for convenience (is_ld_o = (wb_sel_o == MUX_WB_MEM) && is_wb_o)
    output logic             is_st_o,

    // decoded instruction fields
    output logic [4:0]       rs1_addr_o,
    output logic [4:0]       rs2_addr_o,
    output logic [4:0]       rd_addr_o,
    output logic [XLEN-1:0]  immed_o,

    output compare_op_e      compare_op_o,
    output memop_width_e     memop_width_o,
    output logic             ld_unsigned_o
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
        alu_op_o        = ALU_ADD;
        pc_sel_o        = MUX_PC_NEXT;
        alu_op1_sel_o     = MUX_ALU_OP1_RS1;
        alu_op2_sel_o     = MUX_ALU_OP2_RS2;
        wb_sel_o        = MUX_WB_ALU;
        is_wb_o         = 1'b0;
        is_ld_o         = 1'b0;
        is_st_o         = 1'b0;
        illegal_ins_o   = 1'b0;
        compare_op_o    = COMPARE_OP_NONE;
        ld_unsigned_o = 1'b0;

        case (opcode)
            // x[rd] = sext(immediate[31:12] << 12)
            OPCODE_LUI: begin
                is_wb_o     = 1'b1;
                alu_op1_sel_o = MUX_ALU_OP1_RS1; // rs1_addr_o should be x0
                alu_op2_sel_o = MUX_ALU_OP2_IMM;
                alu_op_o    = ALU_ADD; // x[rd] = 0 + imm
            end

            // x[rd] = pc + sext(immediate[31:12] << 12)
            OPCODE_AUIPC: begin
                is_wb_o     = 1'b1;
                alu_op1_sel_o = MUX_ALU_OP1_PC;
                alu_op2_sel_o = MUX_ALU_OP2_IMM;
                alu_op_o    = ALU_ADD; // x[rd] = pc + imm
            end

            // x[rd] = pc+4; pc += sext(offset)
            OPCODE_JAL: begin
                is_wb_o     = 1'b1;
                wb_sel_o    = MUX_WB_PC_NEXT;
                pc_sel_o    = MUX_PC_JAL;
                alu_op1_sel_o   = MUX_ALU_OP1_PC;
                alu_op2_sel_o   = MUX_ALU_OP2_RS1;
            end

            // t = pc+4; pc=(x[rs1]+sext(offset))&∼1; x[rd]=t
            OPCODE_JALR: begin
                is_wb_o     = 1'b1;
                wb_sel_o    = MUX_WB_PC_NEXT;
                pc_sel_o    = MUX_PC_JALR;
                alu_op1_sel_o   = MUX_ALU_OP1_RS1;
                alu_op2_sel_o   = MUX_ALU_OP2_IMM;
            end

            OPCODE_BRANCH: begin
                pc_sel_o    = MUX_PC_BRANCH;
                alu_op1_sel_o   = MUX_ALU_OP1_PC;
                alu_op2_sel_o   = MUX_ALU_OP2_IMM;
                case (funct3)
                    F3_BEQ:   compare_op_o  = COMPARE_OP_BEQ;
                    F3_BNE:   compare_op_o  = COMPARE_OP_BNE;
                    F3_BLT:   compare_op_o  = COMPARE_OP_BLT;
                    F3_BGE:   compare_op_o  = COMPARE_OP_BGE;
                    F3_BLTU:  compare_op_o  = COMPARE_OP_BLTU;
                    default:  illegal_ins_o = 1'b1;
                endcase
            end

            OPCODE_LOAD: begin
                is_wb_o     = 1'b1;
                is_ld_o     = 1'b1;
                alu_op2_sel_o = MUX_ALU_OP2_IMM;
                alu_op_o    = ALU_ADD;    // address calculation: rs1 + imm
                wb_sel_o    = MUX_WB_MEM; // result comes from dmem

                case (funct3)
                    F3_LB:  memop_width_o = MEMOP_WIDTH_8;
                    F3_LH:  memop_width_o = MEMOP_WIDTH_16;
                    F3_LW:  memop_width_o = MEMOP_WIDTH_32;
                    F3_LBU: begin
                        memop_width_o = MEMOP_WIDTH_8;
                        ld_unsigned_o = 1;
                    end
                    F3_LHU: begin
                        memop_width_o = MEMOP_WIDTH_16;
                        ld_unsigned_o = 1;
                    end
                    default: illegal_ins_o = 1'b1;
                endcase
            end

            // store types (SB, SH, SW), funct3 decides which one
            OPCODE_STORE: begin
                is_st_o     = 1'b1;
                alu_op2_sel_o = MUX_ALU_OP2_IMM;
                alu_op_o    = ALU_ADD; // address calculation: rs1 + imm
                case (funct3)
                    F3_BEQ:  compare_op_o = COMPARE_OP_BEQ;
                    F3_BNE:  compare_op_o = COMPARE_OP_BNE;
                    F3_BLT:  compare_op_o = COMPARE_OP_BLT;
                    F3_BGE:  compare_op_o = COMPARE_OP_BGE;
                    F3_BLTU: compare_op_o = COMPARE_OP_BLTU;
                    default:  illegal_ins_o = 1'b1;
                endcase
            end

            OPCODE_IMM: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                is_wb_o     = 1'b1;
                alu_op2_sel_o = MUX_ALU_OP2_IMM;
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
                is_wb_o     = 1'b1;
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
