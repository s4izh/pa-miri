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
    logic [XLEN-1:0]  csr_data_tmp;

    decoupling_reg #(
        .regtype_t(signals_csr_in_t)
    ) decoupling_reg_2d_3e_inst (
        .clk,
        .reset_n,
        .stall_i(stall_i),
        .d_i(_i),
        .q_o(_i_q)
    );

    always_comb begin
        if (noop_i | stall_i) begin
            _o_d.valid = 0;
        end else begin
            _o_d.valid = _i_q.valid;
        end
    end

    assign _o_d.robid = _i_q.robid;

    // CSR "ALU"
    always_comb begin
        _o_d = '0;
        csr_data_tmp = '0;

        case (_i_q.csr_op)
            CSR_OP_RW: begin
                _o_d.rd_we   = (_i_q.rd_addr != '0);
                _o_d.csr_we  = 1;
                if (uimm_valid) csr_data_tmp = $unsigned(_i_q.uimm);
                else            csr_data_tmp = _i_q.rs1_data;
            end
            CSR_OP_RS: begin
                _o_d.rd_we   = 1;
                if (uimm_valid) begin
                    _o_d.csr_we  = (_i_q.uimm != '0);
                    csr_data_tmp = _i_q.csr_data | $unsigned(_i_q.uimm);
                end else begin
                    _o_d.csr_we  = (_i_q.rs1_addr != '0);
                    csr_data_tmp = _i_q.csr_data | _i_q.rs1_data;
                end
            end
            CSR_OP_RC: begin
                _o_d.rd_we   = 1;
                if (uimm_valid) begin
                    _o_d.csr_we  = (_i_q.uimm != '0);
                    csr_data_tmp = _i_q.csr_data | $unsigned(_i_q.uimm);
                end else begin
                    _o_d.csr_we  = (_i_q.rs1_addr != '0);
                    csr_data_tmp = _i_q.csr_data | _i_q.rs1_data;
                end
            end
            default: begin
                csr_data_tmp = '0;
            end
        endcase
        _o_d.rd_data  = _o_d.csr_data;
        _o_d.csr_data = csr_data_tmp;
    end

    // _o_d.()

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
        end else begin
            _o.valid = _o_q.valid;
        end
    end


endmodule
