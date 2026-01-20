import rv_datapath_pkg::*;
import rob_pkg::*;
import store_buffer_pkg::*;

module stage_2d #(
    parameter int XLEN = 32,
    parameter int NREG = 32
) (
    input logic clk,
    input logic reset_n,
    // Pipeline input/output
    input  signals_fetch_t         _i,
    output signals_decode_t        _o_alumem,
    output signals_muldiv_in_t     _o_muldiv,
    output signals_csr_in_t        _o_csr,
    // Write-back - Scalar Register
    input  logic                    rd_we_i,
    input  logic [$clog2(NREG)-1:0] rd_addr_i,
    input  logic [XLEN-1:0]         rd_data_i,
    // Write-back - CSR
    input  logic                    csr_we_i,
    input  logic [11:0]             csr_waddr_i,
    input  logic [XLEN-1:0]         csr_wdata_i,
    // Exceptions
    output logic [XLEN-1:0]         csr_mtvec_o,
    output logic                    xcpt_2d_o,
    // Hazard detection
    input  logic                    noop_i,
    input  logic                    stall_i,
    input  logic                    bypass_rs1_sel_i,
    input  logic                    bypass_rs2_sel_i,
    input  logic                    bypass_csr_sel_i,
    input  logic [XLEN-1:0]         bypass_rs1_data_i,
    input  logic [XLEN-1:0]         bypass_rs2_data_i,
    input  logic [XLEN-1:0]         bypass_csr_data_i,
    input  logic                    bypass_4m_3e_sel_i,
    output logic [$clog2(NREG)-1:0] rs1_addr_o,
    output logic                    rs1_valid_o,
    output logic [$clog2(NREG)-1:0] rs2_addr_o,
    output logic                    rs2_valid_o,
    output logic [11:0]             csr_raddr_o,
    output logic                    csr_re_o,
    output logic                    is_st_o,
    // rob
    output logic                    rob_issue_req_valid_o,
    input  robid_t                  robid_i,
    output issue_req_csr_t          rob_issue_req_csr_o,
    input  logic                    rob_commit_xcpt_valid_i,
    input  logic [XLEN-1:0]         rob_commit_xcpt_pc_i,
    // store buffer allocation interface
    input  sbid_t                   sb_alloc_idx_i,
    output logic                    sb_alloc_en_o
);

    logic [$clog2(NREG)-1:0] rs1_addr, rs2_addr;
    logic is_wb, is_st, is_muldiv, is_csr;
    mux_pc_sel_e pc_sel;
    logic [XLEN-1:0] rf_rs1_data, rf_rs2_data;
    logic noop_q;

    logic            dec_csr_re, dec_csr_we;
    logic [11:0]     dec_csr_raddr;
    logic [XLEN-1:0] csr_rf_rdata;

    logic xcpt_decoder, xcpt_csr_rf;

    capture_xcpt_t capture_xcpt_csr;

    assign capture_xcpt_csr.valid = rob_commit_xcpt_valid_i;
    assign capture_xcpt_csr.pc    = rob_commit_xcpt_pc_i;

    assign csr_re_o    = dec_csr_re;
    assign csr_raddr_o = dec_csr_raddr;

    assign xcpt_2d_o = (xcpt_decoder & _i.valid & ~(noop_i | noop_q | stall_i)) | _i.xcpt; // | xcpt_csr_rf;

    assign is_st_o = is_st;
    assign rs1_addr_o  = rs1_addr;
    assign rs2_addr_o  = rs2_addr;

    // ALUMEM fu
    assign _o_alumem.pc       = _i.pc;
    assign _o_alumem.rs1_data = (bypass_rs1_sel_i == '1) ? bypass_rs1_data_i : rf_rs1_data;
    assign _o_alumem.rs2_data = (bypass_rs2_sel_i == '1) ? bypass_rs2_data_i : rf_rs2_data;

    assign _o_alumem.bypass_4m_3e_sel = bypass_4m_3e_sel_i;
    assign _o_alumem.robid            = robid_i;
    assign _o_alumem.xcpt             = 0;

    // MULDIV fu
    assign _o_muldiv.rs1   = (bypass_rs1_sel_i == '1) ? bypass_rs1_data_i : rf_rs1_data;
    assign _o_muldiv.rs2   = (bypass_rs2_sel_i == '1) ? bypass_rs2_data_i : rf_rs2_data;
    assign _o_muldiv.robid = robid_i;

    // CSR fu
    assign _o_csr.csr_data = (bypass_csr_sel_i == '1) ? bypass_csr_data_i : csr_rf_rdata;
    assign _o_csr.rs1_data = (bypass_rs1_sel_i == '1) ? bypass_rs1_data_i : rf_rs1_data;
    assign _o_csr.uimm     = rs1_addr;
    assign _o_csr.robid    = robid_i;
    // CSR issue req
    assign rob_issue_req_csr_o.csr_we   = is_csr & dec_csr_we;
    assign rob_issue_req_csr_o.csr_addr = dec_csr_raddr;

    // STORE BUFFER
    assign _o_alumem.sbid = sb_alloc_idx_i;
    assign sb_alloc_en_o  = _i.valid & is_st & ~stall_i & ~noop_i & ~noop_q;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            noop_q <= 0;
        end else begin
            if (stall_i && noop_i) begin
                noop_q <= '1;
            end else if (!stall_i) begin
                noop_q <= '0;
            end
        end
    end

    assign rob_issue_req_valid_o = (~(noop_i | noop_q | stall_i) & _i.valid) | xcpt_2d_o;
    always_comb begin
        if (noop_i | noop_q | stall_i | xcpt_2d_o) begin
            // NOOP ALL WAYS
            // alumem fu
            _o_alumem.valid  = 0;
            _o_alumem.is_wb  = 0;
            _o_alumem.is_st  = 0;
            _o_alumem.pc_sel = MUX_PC_NEXT;
            _o_alumem.ins    = 32'h00000033; // noop (add x0, x0, x0)
            // muldiv fu
            _o_muldiv.valid  = 0;
            _o_muldiv.ins    = 32'h00000033; // noop (add x0, x0, x0)
            // csr fu
            _o_csr.valid    = 0;
            _o_csr.ins      = 32'h00000033; // noop (add x0, x0, x0)
            // branch predictor control
            _o_alumem.pred_taken   = 0;
            _o_alumem.pred_target  = 0;
        end else if (is_muldiv) begin
            // ISSUE MULDIV
            // alumem fu
            _o_alumem.valid       = 0;
            _o_alumem.is_wb       = 0;
            _o_alumem.is_st       = 0;
            _o_alumem.pc_sel      = MUX_PC_NEXT;
            _o_alumem.ins         = 32'h00000033; // noop (add x0, x0, x0)
            // muldiv fu
            _o_muldiv.valid       = _i.valid;
            _o_muldiv.ins         = _i.ins;
            // csr fu
            _o_csr.valid          = 0;
            _o_csr.ins            = 32'h00000033; // noop (add x0, x0, x0)
            // branch predictor control
            _o_alumem.pred_taken  = _i.pred_taken;
            _o_alumem.pred_target = _i.pred_target;
        end else if (is_csr) begin
            // ISSUE CSR
            // alumem fu
            _o_alumem.valid       = 0;
            _o_alumem.is_wb       = 0;
            _o_alumem.is_st       = 0;
            _o_alumem.pc_sel      = MUX_PC_NEXT;
            _o_alumem.ins         = 32'h00000033; // noop (add x0, x0, x0)
            // muldiv fu
            _o_muldiv.valid       = 0;
            _o_muldiv.ins         = 32'h00000033; // noop (add x0, x0, x0)
            // csr fu
            _o_csr.valid          = _i.valid;
            _o_csr.ins            = _i.ins;
            // branch predictor control
            _o_alumem.pred_taken  = _i.pred_taken;
            _o_alumem.pred_target = _i.pred_target;
        end else begin
            // ISSUE ALUMEM
            // alumem fu
            _o_alumem.valid       = _i.valid;
            _o_alumem.is_wb       = is_wb;
            _o_alumem.is_st       = is_st;
            _o_alumem.pc_sel      = pc_sel;
            _o_alumem.ins         = _i.ins;
            // muldiv fu
            _o_muldiv.valid       = 0;
            _o_muldiv.ins         = 32'h00000033; // noop (add x0, x0, x0)
            // csr fu
            _o_csr.valid          = 0;
            _o_csr.ins            = 32'h00000033; // noop (add x0, x0, x0)
            // branch predictor control
            _o_alumem.pred_taken  = _i.pred_taken;
            _o_alumem.pred_target = _i.pred_target;
        end
    end

    rv_decoder #(
        .XLEN(XLEN)
    ) dec_inst (
        .ins_i(_i.ins),

        .alu_op_o(_o_alumem.alu_op),
        .alu_op1_sel_o(_o_alumem.alu_op1_sel),
        .alu_op2_sel_o(_o_alumem.alu_op2_sel),
        .wb_sel_o(_o_alumem.wb_sel),

        .pc_sel_o(pc_sel),
        .illegal_ins_o(xcpt_decoder),

        .is_wb_o(is_wb),
        .is_ld_o(_o_alumem.is_ld),
        .is_st_o(is_st),

        .rs1_addr_o(rs1_addr),
        .rs1_valid_o(rs1_valid_o),
        .rs2_addr_o(rs2_addr),
        .rs2_valid_o(rs2_valid_o),
        .rd_addr_o(_o_alumem.rd_addr),
        .immed_o(_o_alumem.immed),

        .compare_op_o(_o_alumem.compare_op),
        .memop_width_o(_o_alumem.memop_width),
        .ld_unsigned_o(_o_alumem.ld_unsigned),

        .is_muldiv_o(is_muldiv),
        .muldiv_op_o(_o_muldiv.op),

        .is_csr_o(is_csr),
        .csr_we_o(dec_csr_we),
        .csr_re_o(dec_csr_re),
        .csr_addr_o(dec_csr_raddr),
        .csr_op_o(_o_csr.csr_op),
        .csr_uses_uimm_o(_o_csr.uimm_valid),

        .is_fence_o(_o_alumem.is_fence)
    );

    csr_regfile #(
        .XLEN(XLEN)
    ) csr_regs_inst (
        .clk,
        .reset_n,
        .read_en_i(dec_csr_re),
        .read_addr_i(dec_csr_raddr),
        .read_data_o(csr_rf_rdata),

        .write_en_i(csr_we_i),
        .write_addr_i(csr_waddr_i),
        .write_data_i(csr_wdata_i),

        .capture_xcpt_i(capture_xcpt_csr),
        .xcpt_o(xcpt_csr_rf),

        .csr_mtvec_o(csr_mtvec_o)
    );

    rv_regfile #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) regs_inst (
        .clk,
        .reset_n,

        .rs1_addr_i(rs1_addr),
        .rs1_data_o(rf_rs1_data),

        .rs2_addr_i(rs2_addr),
        .rs2_data_o(rf_rs2_data),

        .rd_addr_i(rd_addr_i),
        .rd_data_i(rd_data_i),
        .rd_we_i(rd_we_i)
    );

endmodule
