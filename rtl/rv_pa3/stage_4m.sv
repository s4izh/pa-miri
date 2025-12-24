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
    input dmem_if_in_t   dmem_i,
    // Trap
    input logic          noop_i

);
    `define PROPAGATE(signal) assign _o.signal = _i.signal

    logic [XLEN-1:0] dmem_data_sign_extended;

    always_comb begin
        if (noop_i) begin
            _o.valid  = 0;
            _o.is_wb  = 0;
            _o.ins    = 0'h00000033;
        end else begin
            _o.valid  = _i.valid;
            _o.is_wb  = _i.is_wb;
            _o.ins    = _i.ins;
        end
    end

    `PROPAGATE(pc);

    `PROPAGATE(wb_sel);
    `PROPAGATE(rd_addr);

    `PROPAGATE(alu_result);

    assign dmem_o.valid = (_i.is_ld | _i.is_st) & _i.valid;
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
