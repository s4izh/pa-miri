import rv_datapath_pkg::*;
import rv_branch_compare_pkg::*;
import memory_controller_pkg::*;
import alu_pkg::*;
import rv_isa_pkg::*;

module rv_pa2# (
    parameter int XLEN = 32,
    parameter int N_PHY_REG = 32
)(
    input  logic clk,
    input  logic reset_n,

    output logic[XLEN-1:0]  imem_addr_o,
    input  logic[XLEN-1:0]  imem_data_i,
    input  trap_t           imem_trap_i,

    output memop_width_e    dmem_width_o,
    output logic            dmem_memop_valid_o,
    output logic[XLEN-1:0]  dmem_addr_o,
    output logic[XLEN-1:0]  dmem_data_o,
    output logic            dmem_we_o,
    input  logic[XLEN-1:0]  dmem_data_i,
    input  trap_t           dmem_trap_i
);

    localparam int RALEN = $clog2(N_PHY_REG);

    // pc
    logic [XLEN-1:0] pc;
    // trap control signals
    logic trap_valid, xcpt_illegal_ins;
    // branch control
    logic taken_branch;
    // mux selectors
    mux_pc_sel_e pc_sel;
    mux_wb_sel_e wb_sel;
    // pipeline stages data
    signals_fetch_t     s_1f_d, s_1f_q;
    signals_decode_t    s_2d_d, s_2d_q;
    signals_execute_t   s_3e_d, s_3e_q;
    signals_memory_t    s_4m_d, s_4m_q;
    signals_writeback_t s_5w_d;
    // data mem interfacing
    dmem_if_in_t  dmem_if_in;
    dmem_if_out_t dmem_if_out;

    // local assigns
    assign trap_valid =
        imem_trap_i.valid |
        (dmem_trap_i.valid & s_4m_d.valid) |
        (xcpt_illegal_ins & s_2d_d.valid);

    assign dmem_if_in.data = dmem_data_i;
    assign dmem_if_in.trap = dmem_trap_i;

    assign dmem_memop_valid_o = dmem_if_out.valid;
    assign dmem_we_o          = dmem_if_out.we;
    assign dmem_addr_o        = dmem_if_out.addr;
    assign dmem_data_o        = dmem_if_out.data;
    assign dmem_width_o       = dmem_if_out.width;

    // =========================================================================
    // = Stage 1: Fetch
    // =========================================================================
    // pc
    always @(posedge clk) begin
        if (!reset_n) begin
            pc <= 'h1000;
        end else begin
            if (trap_valid) begin
                pc <= 'h2000;
            end else begin
                case (pc_sel)
                    MUX_PC_NEXT:
                        pc <= pc + 4;
                    MUX_PC_BRANCH:
                        if (taken_branch)
                            pc <= s_3e_d.alu_result;
                        else
                            pc <= pc + 4;
                    MUX_PC_JAL:
                        pc <= s_3e_d.alu_result;
                    MUX_PC_JALR:
                        pc <= {s_3e_d.alu_result[31:1], 1'b0};
                endcase
            end
        end
    end

    // external interface
    assign imem_addr_o = pc;

    // pipeline
    assign s_1f_d.valid = reset_n;
    assign s_1f_d.pc = pc;
    assign s_1f_d.ins = imem_data_i;

    decoupling_reg #(
        .regtype_t(signals_fetch_t)
    ) decoupling_reg_1f_2d_inst (
        .clk,
        .reset_n,
        .stall_i(0),
        .d_i(s_1f_d),
        .q_o(s_1f_q)
    );

    // =========================================================================
    // = Stage 2: Decode
    // =========================================================================
    stage_2d #(
        .XLEN(XLEN),
        .NREG(N_PHY_REG)
    ) stage_2d_inst (
        .clk,
        .reset_n,
        // Pipeline input/output
        ._i(s_1f_q),
        ._o(s_2d_d),
        // Write-back
        .rd_we_i(s_5w_d.is_wb),
        .rd_addr_i(s_5w_d.rd_addr),
        .rd_data_i(s_5w_d.rd_data),
        // Exceptions
        .xcpt_illegal_ins_o(xcpt_illegal_ins)
    );

    decoupling_reg #(
        .regtype_t(signals_decode_t)
    ) decoupling_reg_2d_3e_inst (
        .clk,
        .reset_n,
        .stall_i(0),
        .d_i(s_2d_d),
        .q_o(s_2d_q)
    );

    // =========================================================================
    // = Stage 3: Execute
    // =========================================================================
    stage_3e #(
        .XLEN(XLEN)
    ) stage_3e_inst (
        .clk,
        .reset_n,
        // Pipeline input/output
        ._i(s_2d_q),
        ._o(s_3e_d),
        // Next pc selection
        .pc_sel_o(pc_sel),
        .taken_branch_o(taken_branch)
    );

    decoupling_reg #(
        .regtype_t(signals_execute_t)
    ) decoupling_reg_3e_4m_inst (
        .clk,
        .reset_n,
        .stall_i(0),
        .d_i(s_3e_d),
        .q_o(s_3e_q)
    );

    // =========================================================================
    // = Stage 4: Memory
    // =========================================================================
    stage_4m #(
        .XLEN(XLEN)
    ) stage_4m_inst (
        .clk,
        .reset_n,
        // Pipeline input/output
        ._i(s_3e_q),
        ._o(s_4m_d),
        // Interface with dmem
        .dmem_o(dmem_if_out),
        .dmem_i(dmem_if_in)
    );

    decoupling_reg #(
        .regtype_t(signals_memory_t)
    ) decoupling_reg_4m_5w_inst (
        .clk,
        .reset_n,
        .stall_i(0),
        .d_i(s_4m_d),
        .q_o(s_4m_q)
    );

    // =========================================================================
    // = Stage 5: Write-back
    // =========================================================================
    always_comb begin
        case (s_4m_q.wb_sel)
            MUX_WB_ALU:
                s_5w_d.rd_data = s_4m_q.alu_result;
            MUX_WB_MEM:
                s_5w_d.rd_data = s_4m_q.mem_result;
            MUX_WB_PC_NEXT:
                s_5w_d.rd_data = s_4m_q.pc + 4;
            default:
                s_5w_d.rd_data = s_4m_q.pc + 4;
        endcase
    end

    assign s_5w_d.is_wb   = s_4m_q.is_wb && s_4m_d.valid;
    assign s_5w_d.rd_addr = s_4m_q.rd_addr;

endmodule

