`ifndef _RV_DATAPATH_PKG_
`define _RV_DATAPATH_PKG_

package rv_datapath_pkg;
    typedef enum logic [0:0] {
        MUX_ALU_OP1_RS1,
        MUX_ALU_OP1_PC
    } mux_alu_op1_sel_e;

    typedef enum logic [0:0] {
        MUX_ALU_OP2_RS2,
        MUX_ALU_OP2_IMM
    } mux_alu_op2_sel_e;

    typedef enum logic [1:0] {
        MUX_WB_ALU,
        MUX_WB_MEM,
        MUX_WB_PC_NEXT // for JAL/JALR
    } mux_wb_sel_e;

    typedef enum logic [1:0] {
        MUX_PC_NEXT,      // PC = PC + 4 (default sequential execution)
        MUX_PC_BRANCH,    // PC = PC + immediate (conditional branch taken)
        MUX_PC_JAL,       // PC = PC + immediate (unconditional jump - JAL)
        MUX_PC_JALR       // PC = rs1 + immediate (unconditional jump - JALR)
    } mux_pc_sel_e;

    typedef enum logic [2:0] {
        COMPARE_OP_BEQ,
        COMPARE_OP_BNE,
        COMPARE_OP_BLT,
        COMPARE_OP_BGE,
        COMPARE_OP_BGEU,
        COMPARE_OP_BLTU,
        COMPARE_OP_NONE
    } compare_op_e;
endpackage

`endif
