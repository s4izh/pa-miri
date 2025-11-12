import rv_datapath_pkg::*;

module stage_4m #(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic reset_n,
    // Pipeline input/output
    input  signals_execute_t _i,
    output signals_memory_t  _o,
    // Interface with dmem
    output dmem_if_out_t dmem_o,
    input dmem_if_in_t   dmem_i

);
    logic [XLEN-1:0] dmem_data_sign_extended;

    assign _o.valid = _i.valid;
    assign _o.pc    = _i.pc;

    assign _o.is_wb   = _i.is_wb;
    assign _o.wb_sel  = _i.wb_sel;
    assign _o.rd_addr = _i.rd_addr;

    assign _o.alu_result = _i.alu_result;

    assign dmem_o.valid = _i.is_ld || _i.is_st;
    assign dmem_o.we    = _i.is_st;
    assign dmem_o.addr  = _i.alu_result;
    assign dmem_o.data  = _i.rs2_data;
    assign dmem_o.width = _i.memop_width;

    sign_extender #(
        .XLEN(XLEN)
    ) sign_extender_inst (
        .data_i        (dmem_i.data),
        .width_i       (_i.memop_width),
        .data_signed_o (dmem_data_sign_extended)
    );

    always_comb begin
        if (_i.ld_unsigned == 1)
            _o.mem_result = dmem_i.data;
        else
            _o.mem_result = dmem_data_sign_extended;
    end

endmodule
