import rv_datapath_pkg::*;

module csr_fu #(
    parameter int XLEN = 32
) (
    input  logic clk,
    input  logic reset_n,

    input  signals_csr_in_t  _i,
    output signals_csr_out_t _o,
    input  logic             noop_i,
    input  logic             stall_i
);
    signals_csr_in_t  _i_q;
    signals_csr_out_t _o_d, _o_q;

    decoupling_reg #(
        .regtype_t(signals_csr_in_t)
    ) decoupling_reg_2d_3e_inst (
        .clk,
        .reset_n,
        .stall_i(stall_i),
        .d_i(_i),
        .q_o(_i_q)
    );

    logic [XLEN-1:0] csr_data_tmp;
    logic [XLEN-1:0] uimm_extended;
    assign uimm_extended = { {(XLEN-5){1'b0}}, _i_q.uimm };

    assign _o_d.valid    = _i_q.valid & ~(noop_i | stall_i);
    assign _o_d.ins      = _i_q.ins;
    assign _o_d.rd_data  = _i_q.csr_data;
    assign _o_d.csr_data = csr_data_tmp;
    assign _o_d.robid    = _i_q.robid;
    assign _o_d.xcpt     = 0;

    // CSR "ALU"
    always_comb begin
        csr_data_tmp = '0;
        case (_i_q.csr_op)
            CSR_OP_RW: begin
                if (_i_q.uimm_valid) csr_data_tmp = uimm_extended;
                else                 csr_data_tmp = _i_q.rs1_data;
            end
            CSR_OP_RS: begin
                if (_i_q.uimm_valid) csr_data_tmp = _i_q.csr_data | uimm_extended;
                else                 csr_data_tmp = _i_q.csr_data | _i_q.rs1_data;
            end
            CSR_OP_RC: begin
                if (_i_q.uimm_valid) csr_data_tmp = _i_q.csr_data & ~uimm_extended;
                else                 csr_data_tmp = _i_q.csr_data & ~_i_q.rs1_data;
            end
            default: begin
                csr_data_tmp = '0;
            end
        endcase
    end

    decoupling_reg #(
        .regtype_t(signals_csr_out_t)
    ) decoupling_reg_3e_4w_inst (
        .clk,
        .reset_n,
        .stall_i(stall_i),
        .d_i(_o_d),
        .q_o(_o_q)
    );

    always_comb begin
        _o = _o_q;
        if (noop_i | stall_i) begin
            _o.valid = 0;
        end
    end


endmodule
