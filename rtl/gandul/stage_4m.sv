import rv_datapath_pkg::*;

module stage_4m #(
    parameter int XLEN = 32,
    parameter int WAYS = 4,
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128
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
    input logic          stall_i,
    input logic          noop_i,

    output logic         waiting_for_memory_o
);
    `define PROPAGATE(signal) assign _o.signal = _i.signal

    logic [XLEN-1:0] data_sign_extended;
    logic [XLEN-1:0] drsp_data;
    logic            dreq_ready;
    logic            dcache_xcpt;

    assign waiting_for_memory_o = ~dreq_ready;

    always_comb begin
        if (noop_i | stall_i) begin
            _o.valid  = 0;
            _o.is_wb  = 0;
            _o.ins    = 0'h00000033;
        end else begin
            _o.valid  = _i.valid;
            _o.is_wb  = _i.is_wb;
            _o.ins    = _i.ins;
        end

        if (_i.xcpt) begin
            _o.xcpt = _i.xcpt;
        end else begin
            _o.xcpt = dcache_xcpt;
        end

    end

    `PROPAGATE(pc);
    `PROPAGATE(wb_sel);
    `PROPAGATE(rd_addr);
    `PROPAGATE(alu_result);
    `PROPAGATE(robid);

    sign_extender #(
        .XLEN(XLEN)
    ) sign_extender_inst (
        .data_i        (drsp_data),
        .width_i       (_i.memop_width),
        .data_signed_o (data_sign_extended)
    );

    dcache_wrapper #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) dcache_inst (
        .clk,
        .reset_n,

        .dreq_valid_i((_i.is_ld | _i.is_st) & _i.valid),
        .dreq_ready_o(dreq_ready),
        .dreq_addr_i(_i.alu_result),
        .dreq_data_i(_i.rs2_data),
        .dreq_we_i(_i.is_st),
        .dreq_width_i(_i.memop_width),

        .drsp_data_o(drsp_data),
        .drsp_xcpt_o(dcache_xcpt),

        .freq_valid_o(dmem_o.valid),
        .freq_we_o(dmem_o.we),
        .freq_data_o(dmem_o.data),
        .freq_addr_o(dmem_o.addr),

        .frsp_valid_i(dmem_i.valid),
        .frsp_data_i(dmem_i.data)
    );

    always_comb begin
        if (_i.ld_unsigned == 1)
            _o.mem_result = drsp_data;
        else
            _o.mem_result = data_sign_extended;
    end

endmodule
