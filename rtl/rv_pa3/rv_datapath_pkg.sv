`ifndef _RV_DATAPATH_PKG_
`define _RV_DATAPATH_PKG_

package rv_datapath_pkg;
    `define INS_WIDTH 32
    `define XLEN 32
    import rv_isa_pkg::*;
    import alu_pkg::*;
    import rv_branch_compare_pkg::*;
    import memory_controller_pkg::*;

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
    } signals_fetch_t;

    typedef struct packed {
        logic             valid;
        logic [`INS_WIDTH-1:0] ins;
        // outputs for datapath control
        alu_op_e          alu_op;
        mux_alu_op1_sel_e alu_op1_sel;
        mux_alu_op2_sel_e alu_op2_sel;
        mux_wb_sel_e      wb_sel;

        mux_pc_sel_e      pc_sel;

        // write enable signals
        logic             is_wb;
        logic             is_ld; // kept for convenience (is_ld_o = (wb_sel_o == MUX_WB_MEM) && is_wb_o)
        logic             is_st;

        // decoded instruction fields
        logic [`XLEN-1:0] rs1_data;
        logic [`XLEN-1:0] rs2_data;
        logic [4:0]       rd_addr;
        logic [`XLEN-1:0] immed;

        compare_op_e      compare_op;

        // memory signals
        memop_width_e     memop_width;
        logic             ld_unsigned;

        // bypasses
        logic             bypass_4m_3e_sel;

        logic [`XLEN-1:0] pc;
    } signals_decode_t;

    typedef struct packed {
        logic             valid;
        logic [`INS_WIDTH-1:0] ins;
        logic [`XLEN-1:0] alu_result;
        mux_wb_sel_e      wb_sel;
        logic [4:0]       rd_addr;

        // write enable signals
        logic             is_wb;
        logic             is_ld; // kept for convenience (is_ld_o = (wb_sel_o == MUX_WB_MEM) && is_wb_o)
        logic             is_st;

        // memory signals
        memop_width_e     memop_width;
        logic             ld_unsigned;
        logic [`XLEN-1:0] rs2_data;


        logic [`XLEN-1:0] pc;
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

        logic [`XLEN-1:0] pc;
    } signals_memory_t;

    typedef struct packed {
        logic [`INS_WIDTH-1:0] ins;
        logic [`XLEN-1:0] rd_data;
        logic [4:0]       rd_addr;

        // write enable signals
        logic             is_wb;
    } signals_writeback_t;


    // Data memory interfacing structs
    typedef struct packed {
        logic             valid;
        logic             we;
        logic [`XLEN-1:0] addr;
        logic [`XLEN-1:0] data;
        memop_width_e     width;
    } dmem_if_out_t;

    typedef struct packed {
        logic [`XLEN-1:0] data;
        trap_t            trap;
    } dmem_if_in_t;

endpackage

`endif
