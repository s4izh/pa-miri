import rv_datapath_pkg::*;

module stage_3e #(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic reset_n,
    // Pipeline input/output
    input  signals_decode_t  _i,
    output signals_execute_t _o,
    // Next pc selection
    output mux_pc_sel_e     pc_sel_o,
    output logic            taken_branch_o,
    // Bypass
    input logic [XLEN-1:0]  bypass_4m_3e_data_i,
    // Trap
    input logic             noop_i,
    input logic             stall_i
);
    `define PROPAGATE(signal) assign _o.signal = _i.signal

    logic [XLEN-1:0] alu_op1, alu_op2;
    logic noop_q;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            noop_q <= 0;
        end else begin
            if (stall_i) begin
                noop_q <= noop_i;
            end else begin
                noop_q <= '0;
            end
        end
    end

    always_comb begin
        if (noop_i | noop_q | stall_i) begin
            _o.valid  = 0;
            _o.is_wb  = 0;
            // _o.is_ld  = 0;
            _o.is_st  = 0;
            _o.ins = 32'h00000033; // noop (add x0, x0, x0)
        end else begin
            _o.valid  = _i.valid;
            _o.is_wb  = _i.is_wb;
            // _o.is_ld  = _i.is_ld;
            _o.is_st  = _i.is_st;
            _o.ins    = _i.ins;
        end
    end

    // Propagated signals
    `PROPAGATE(pc);

    `PROPAGATE(wb_sel);
    `PROPAGATE(rd_addr);

    `PROPAGATE(is_ld);

    `PROPAGATE(memop_width);
    `PROPAGATE(ld_unsigned);

    `PROPAGATE(robid);
    `PROPAGATE(xcpt);

    `PROPAGATE(sbid);

    assign _o.rs2_data = (_i.bypass_4m_3e_sel) ? bypass_4m_3e_data_i : _i.rs2_data;

    // Outputs
    assign pc_sel_o = (_i.valid == 1) ? _i.pc_sel : MUX_PC_NEXT;

    // Muxes
    always_comb begin
        case(_i.alu_op1_sel)
            MUX_ALU_OP1_RS1:
                alu_op1 = _i.rs1_data;
            MUX_ALU_OP1_PC:
                alu_op1 = _i.pc;
        endcase
    end

    always_comb begin
        case(_i.alu_op2_sel)
            MUX_ALU_OP2_RS2:
                alu_op2 = _i.rs2_data;
            MUX_ALU_OP2_IMM:
                alu_op2 = _i.immed;
        endcase
    end

    // Instances
    alu #(
        .XLEN(XLEN)
    ) alu_inst (
        .op1_i(alu_op1),
        .op2_i(alu_op2),
        .alu_op_i(_i.alu_op),
        .result_o(_o.alu_result)
    );

    rv_branch_compare #(
        .XLEN(XLEN)
    ) cmp_inst (
        .compare_op_i(_i.compare_op),
        .op1_i(_i.rs1_data),
        .op2_i(_i.rs2_data),
        .taken_branch_o(taken_branch_o)
    );

endmodule
