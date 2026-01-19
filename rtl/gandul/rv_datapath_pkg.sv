`ifndef _RV_DATAPATH_PKG_
`define _RV_DATAPATH_PKG_

package rv_datapath_pkg;
    `define INS_WIDTH 32
    `define XLEN 32
    `define BITS_CACHELINE 128
    import rv_isa_pkg::*;
    import alu_pkg::*;
    import rv_branch_compare_pkg::*;
    import memory_controller_pkg::*;
    import rob_pkg::*;
    import store_buffer_pkg::*;

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
        MUX_PC_NEXT = '0, // PC = PC + 4 (default sequential execution)
        MUX_PC_BRANCH,    // PC = PC + immediate (conditional branch taken)
        MUX_PC_JAL,       // PC = PC + immediate (unconditional jump - JAL)
        MUX_PC_JALR       // PC = rs1 + immediate (unconditional jump - JALR)
    } mux_pc_sel_e;

    typedef struct packed {
        logic                  valid;
        logic [`INS_WIDTH-1:0] ins;
        logic [`XLEN-1:0]      pc;
        logic                  xcpt;

        logic                  pred_taken;
        logic [`XLEN-1:0]      pred_target;
    } signals_fetch_t;

    typedef struct packed {
        logic             valid;
        logic [`INS_WIDTH-1:0] ins;
        // Outputs for datapath control
        alu_op_e          alu_op;
        mux_alu_op1_sel_e alu_op1_sel;
        mux_alu_op2_sel_e alu_op2_sel;
        mux_wb_sel_e      wb_sel;
        mux_pc_sel_e      pc_sel;
        // Write enable signals
        logic             is_wb;
        logic             is_ld; // kept for convenience (is_ld_o = (wb_sel_o == MUX_WB_MEM) && is_wb_o)
        logic             is_st;
        // Decoded instruction fields
        logic [`XLEN-1:0] rs1_data;
        logic [`XLEN-1:0] rs2_data;
        logic [4:0]       rd_addr;
        logic [`XLEN-1:0] immed;
        // Compare
        compare_op_e      compare_op;
        // Memory signals
        memop_width_e     memop_width;
        logic             ld_unsigned;
        // Bypasses
        logic             bypass_4m_3e_sel;
        // ROB things
        robid_t           robid;
        logic             xcpt;

        sbid_t            sbid;
        logic             is_fence;

        // PC
        logic [`XLEN-1:0] pc;

        logic             pred_taken;
        logic [`XLEN-1:0] pred_target;
    } signals_decode_t;

    typedef struct packed {
        logic             valid;
        logic [`INS_WIDTH-1:0] ins;
        logic [`XLEN-1:0] alu_result;
        mux_wb_sel_e      wb_sel;
        logic [4:0]       rd_addr;
        // Write enable signals
        logic             is_wb;
        logic             is_ld; // kept for convenience (is_ld_o = (wb_sel_o == MUX_WB_MEM) && is_wb_o)
        logic             is_st;
        // Memory signals
        memop_width_e     memop_width;
        logic             ld_unsigned;
        logic [`XLEN-1:0] rs2_data;
        // ROB things
        robid_t           robid;
        logic             xcpt;

        sbid_t            sbid;
        logic             is_fence;

        // PC
        logic [`XLEN-1:0] pc;

        logic             pred_taken;
        logic [`XLEN-1:0] pred_target;
    } signals_execute_t;

    typedef struct packed {
        logic             valid;
        logic [`INS_WIDTH-1:0] ins;
        logic [`XLEN-1:0] mem_result;
        logic [`XLEN-1:0] alu_result;
        mux_wb_sel_e      wb_sel;
        logic [4:0]       rd_addr;
        // write enable signals
        logic             is_wb;
        // ROB things
        robid_t           robid;
        logic             xcpt;
        sbid_t            sbid;
        // PC
        logic [`XLEN-1:0] pc;
    } signals_memory_t;

    typedef struct packed {
        logic                  valid;
        logic [`INS_WIDTH-1:0] ins;
        logic [`XLEN-1:0] rd_data;
        logic [4:0]       rd_addr;
        // write enable signals
        logic             is_wb;
        // ROB things
        robid_t           robid;
        logic             xcpt;
        sbid_t            sbid;
    } signals_writeback_t;


    // Data memory interfacing structs
    typedef struct packed {
        logic                       valid;
        logic                       we;
        logic [`XLEN-1:0]           addr;
        logic [`BITS_CACHELINE-1:0] data;
    } dmem_if_out_t;

    typedef struct packed {
        logic                       valid;
        logic [`BITS_CACHELINE-1:0] data;
    } dmem_if_in_t;

    typedef enum logic[2:0] {
        MULDIV_OP_MUL,
        MULDIV_OP_MULH,
        MULDIV_OP_MULHSU,
        MULDIV_OP_MULHU,
        MULDIV_OP_DIV,
        MULDIV_OP_DIVU,
        MULDIV_OP_REM,
        MULDIV_OP_REMU
    } muldiv_op_e;

    typedef struct packed {
        logic                       valid;
        logic [`XLEN-1:0]           ins;
        muldiv_op_e                 op;
        logic [`XLEN-1:0]           rs1;
        logic [`XLEN-1:0]           rs2;
        robid_t                     robid;
    } signals_muldiv_in_t;

    typedef struct packed {
        logic                       valid;
        logic                       xcpt;
        logic [`XLEN-1:0]           result;
        robid_t                     robid;
    } signals_muldiv_out_t;

    typedef enum {
        CSR_OP_RW,
        CSR_OP_RS,
        CSR_OP_RC
    } csr_op_e;

    typedef struct packed {
        logic             valid;
        logic [`XLEN-1:0] ins;
        csr_op_e          csr_op;
        logic [`XLEN-1:0] csr_data;
        logic [`XLEN-1:0] rs1_data;
        logic             uimm_valid;
        logic [4:0]       uimm;
        // ROB signals
        robid_t           robid;
    } signals_csr_in_t;

    typedef struct packed {
        logic             valid;
        logic [`XLEN-1:0] ins;
        logic [`XLEN-1:0] rd_data;
        logic [`XLEN-1:0] csr_data;
        robid_t           robid;
        // Exceptions for csr_fu are generated in 2d. So this signal is always 0 (for now)
        logic             xcpt;
    } signals_csr_out_t;


endpackage

`endif
